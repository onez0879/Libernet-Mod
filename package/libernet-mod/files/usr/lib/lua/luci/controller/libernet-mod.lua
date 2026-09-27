module("luci.controller.libernet-mod", package.seeall)
function index()
entry({"admin","services","libernet-mod"}, template("libernet-mod"), _("Libernet Mod"), 11).leaf=true
end