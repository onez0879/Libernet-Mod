<script src="lib/vendor/jquery/jquery-3.6.0.slim.min.js"></script>
<script src="lib/vendor/bootstrap/js/bootstrap.min.js"></script>
<script src="lib/vendor/vuejs/vue.min.js"></script>
<script src="lib/vendor/axios/axios.min.js"></script>
<script>
// Session expired => api.php answers 401. Bounce to the login page instead of
// failing silently, so "nothing happens" never hides an auth problem again.
axios.interceptors.response.use(null, function (err) {
    if (err.response && err.response.status === 401) {
        window.location = 'login.php';
    }
    return Promise.reject(err);
});
</script>
<script src="lib/vendor/sweetalert2/sweetalert2.all.min.js"></script>
<script src="lib/vendor/lodash/lodash.min.js"></script>
