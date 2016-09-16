use strict;
use warnings;
use Data::Dumper;
use HTTP::Request::Common;
use LWP::UserAgent;
use Mojo::JSON ();
use Mojolicious::Lite;

my $client_id = $ENV{APP_CLIENT_ID};

my $app = app();

$app->plugin('xslate_renderer');

my $routes = $app->routes;

$routes->get('/')->name('index')->to(
    cb => sub {
        my $c = shift;
        $c->stash({ client_id => $client_id, });
    }
);

$routes->get('/auth')->name('auth')->to(
    cb => sub {
        my $c        = shift;
        my $params   = $c->req->params->to_hash;
        my $id_token = $params->{id_token};

        my $uri = URI->new('https://www.googleapis.com/oauth2/v3/tokeninfo');
        $uri->query_form({ id_token => $id_token });

        my $res  = LWP::UserAgent->new->request(GET $uri->as_string);
        my $data = Mojo::JSON::decode_json($res->content);

        die "client_id does not match" if $data->{aud} ne $client_id;

        my $google_account = {
            google_account_id => $data->{sub},
            email             => $data->{email},
        };

        $c->stash->{google_account} = $google_account;
    }
);

$app->start;

__DATA__

@@ index.html.tx

<!doctype html>
<html lang="en">
<head>
  <script src="https://apis.google.com/js/api:client.js"></script>
</head>
<body>
<h1>Hello</h1>
<div>
  <button id="google-login"
    data-client-id="<: $client_id :>"
    data-auth-url="<: $c.url_for('auth').to_abs :>"
    >
    Login with Google
  </button>
</div>
<script type="text/javascript">
(function () {
    var buttonEl = document.getElementById('google-login');
    var clientId = buttonEl.getAttribute('data-client-id');
    var authUrl  = buttonEl.getAttribute('data-auth-url');

    var onSuccess = function (user) {
        var id_token = user.getAuthResponse().id_token;
        window.location.href = authUrl + '?id_token=' + encodeURIComponent(id_token);
    };
    var onFailure = function () {
        alert("Something has gone wrong");
    };

    gapi.load('auth2', function () {
        gapi.auth2.init({
            client_id: clientId
        })
        .attachClickHandler(
            buttonEl,
            {},
            onSuccess,
            onFailure
        );
    });
})();
</script>
</body>
</html>

@@ auth.html.tx

<!doctype html>
<html lang="en">
<head>
</head>
<body>
    <h1>Auth success?</h1>

    <dl>
      <dt>Google Account ID</dt>
      <dd><: $google_account.google_account_id :></dd>
      <dt>Email</dt>
      <dd><: $google_account.email :></dd>
    </dl>
</body>
</html>
