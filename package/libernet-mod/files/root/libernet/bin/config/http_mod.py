#!/usr/bin/env python3

import socket
import select
import time
import argparse
import json
import logging

logging.basicConfig(
    filename='/tmp/http-injector.log',
    filemode='a',
    format='%(asctime)s %(levelname)s %(message)s',
    level=logging.INFO
)


class Forwarder:
    def __init__(self):
        self.forward = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.forward.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
        self.forward.settimeout(15)

    def start(self, host, port):
        try:
            self.forward.connect((host, port))
            self.forward.settimeout(None)
            return self.forward
        except Exception as e:
            logging.error(f"Forward connect error: {e}")
            try:
                self.forward.close()
            except Exception:
                pass
            return False


class Server:

    def __init__(self, config, port):
        self.sockets = []
        self.tx_chan = {}
        self.rx_chan = {}
        self.request = {}

        payload_file = json.load(config)

        payload = payload_file['http']['payload']
        payload = payload.replace('[crlf]', '\r\n')
        payload = payload.replace('[lf]', '\n')
        payload = payload.replace('[cr]', '\r')
        payload = payload.replace('[protocol]', 'HTTP/1.1')

        self.payload = payload
        self.forward_to = (
            payload_file['http']['proxy']['ip'],
            payload_file['http']['proxy']['port']
        )
        self.buffer_size = payload_file['http']['buffer']

        self.server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
        self.server.bind(('127.0.0.1', port))
        self.server.listen(200)

        print(f"Config: {payload_file['http']['info']}")
        logging.info(f"Config: {payload_file['http']['info']}")

    def safe_close(self, sock):
        try:
            sock.close()
        except Exception:
            pass

    def on_accept(self):
        clientsock, _ = self.server.accept()

        clientsock.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)

        forward = Forwarder().start(
            self.forward_to[0],
            self.forward_to[1]
        )

        if not forward:
            logging.error("Unable connect to proxy server")
            self.safe_close(clientsock)
            return

        self.sockets.append(clientsock)
        self.sockets.append(forward)

        self.tx_chan[clientsock] = forward
        self.tx_chan[forward] = clientsock

        self.rx_chan[clientsock] = forward
        self.rx_chan[forward] = forward

    def on_close(self, sock):
        peer = self.tx_chan.get(sock)

        for s in [sock, peer]:
            if s and s in self.sockets:
                self.sockets.remove(s)

        if peer:
            self.safe_close(peer)

        self.safe_close(sock)

        for s in [sock, peer]:
            self.tx_chan.pop(s, None)
            self.rx_chan.pop(s, None)
            self.request.pop(s, None)

    def send_data(self, sock, data):
        try:
            sock.sendall(data)
            return True
        except Exception as e:
            logging.error(f"Send error: {e}")
            return False

    def on_execute(self, sock, netdata):
        try:
            text = netdata.decode(errors='ignore')

            if text.startswith('CONNECT'):
                req = text.split('HTTP')[0].strip().split(' ')
                host_port = req[1].split(':')

                payload = self.payload
                payload = payload.replace('[host_port]', req[1])
                payload = payload.replace('[host]', host_port[0])

                if len(host_port) > 1:
                    payload = payload.replace('[port]', host_port[1])

                if '[split]' in payload:
                    pay = payload.split('[split]', 1)
                    self.request[self.tx_chan[sock]] = pay[1]
                    netdata = pay[0].encode()
                else:
                    netdata = payload.encode()

                logging.info("Connecting")

        except Exception as e:
            logging.error(f"Execute error: {e}")

        if not self.send_data(self.tx_chan[sock], netdata):
            self.on_close(sock)

    def on_outbounddata(self, sock, netdata):
        try:
            text = netdata.decode(errors='ignore')

            if text.startswith('HTTP/1.'):

                if '[split]' in self.payload:
                    extra = self.request.get(sock, '')

                    if extra:
                        time.sleep(0.5)
                        self.send_data(
                            self.rx_chan[sock],
                            extra.encode()
                        )
                        self.request[sock] = ''

                netdata = b'HTTP/1.1 200 Connection established\r\n\r\n'

        except Exception as e:
            logging.error(f"Outbound error: {e}")

        if b'zlib@openssh.com' in netdata:
            logging.info("Connected")

        if not self.send_data(self.tx_chan[sock], netdata):
            self.on_close(sock)

    def main_loop(self):

        if self.server not in self.sockets:
            self.sockets.append(self.server)

        while True:

            try:
                readable, _, _ = select.select(
                    self.sockets,
                    [],
                    [],
                    1
                )
            except Exception:
                continue

            for sock in readable:

                if sock == self.server:
                    self.on_accept()
                    continue

                try:
                    netdata = sock.recv(self.buffer_size)
                except Exception:
                    netdata = b''

                if not netdata:
                    logging.info("Disconnected")
                    self.on_close(sock)
                    continue

                if self.tx_chan.get(sock) != self.rx_chan.get(sock):
                    self.on_outbounddata(sock, netdata)
                else:
                    self.on_execute(sock, netdata)


if __name__ == '__main__':

    parser = argparse.ArgumentParser(
        prog='http-injector',
        description='Python Version of HTTP-INJECTOR'
    )

    parser.add_argument(
        'config',
        metavar='payload',
        type=argparse.FileType('r'),
        help='payload file'
    )

    parser.add_argument(
        '-l',
        dest='listen',
        nargs='?',
        const=9876,
        default=9876,
        help='listen port'
    )

    args = parser.parse_args()

    while True:
        try:
            server = Server(args.config, int(args.listen))
            server.main_loop()
        except KeyboardInterrupt:
            break
        except Exception as e:
            logging.error(f"Fatal error: {e}")
            time.sleep(3)
