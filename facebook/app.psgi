use strict;
use warnings;
use Data::Dumper;
use Digest::SHA qw(hmac_sha256);
use HTTP::Request::Common;
use LWP::UserAgent;
use MIME::Base64::URLSafe qw(urlsafe_b64decode);
use Mojo::JSON;
use Mojolicious::Lite;
use URI;

my $app_id     = $ENV{APP_ID};
my $app_secret = $ENV{APP_SECRET};

my $app = app();

$app->plugin('xslate_renderer');

my $routes = $app->routes;

$routes->get('/')->name('index')->to(
    cb => sub {
        my $c = shift;
        $c->stash({ app_id => $app_id });
    }
);

$routes->get('/verify')->name('verify')->to(
    cb => sub {
        my $c              = shift;
        my $params         = $c->req->params->to_hash;
        my $signed_request = $params->{signed_request};
        my $access_token   = $params->{access_token};

        my ($encoded_sig, $encoded_payload) = split /\./, $signed_request;

        my $sig     = urlsafe_b64decode $encoded_sig;
        my $payload = Mojo::JSON::decode_json(urlsafe_b64decode $encoded_payload);

        die "Signature is invalid" if $sig ne hmac_sha256($encoded_payload, $app_secret);

        my $user_id = $payload->{user_id};

        my $uri = URI->new('https://graph.facebook.com');
        $uri->path("/v2.7/${user_id}");
        $uri->query_form(
            {   fields       => 'email',
                access_token => $access_token,
            }
        );

        my $res = LWP::UserAgent->new->request(GET $uri->as_string);
        my $facebook_account = Mojo::JSON::decode_json($res->content);

        $c->stash->{facebook_account} = $facebook_account;
    }
);

$app->start;

__DATA__

@@ index.html.tx

<!doctype html>
<html lang="en">
<head>
</head>
<body>
  <div id="fb-root"></div>
  <script>
  function checkLoginState() {
    FB.getLoginStatus(function (response) {
        if (response.status === 'connected') {
            console.log(response.authResponse);
            window.location.href = "/verify?access_token="
                + encodeURIComponent(response.authResponse.accessToken)
                + "&signed_request="
                + encodeURIComponent(response.authResponse.signedRequest);
        }
        else {
            console.log('NOT connected');
        }
    });
  }

  (function(d, s, id) {
    var js, fjs = d.getElementsByTagName(s)[0];
    if (d.getElementById(id)) return;
    js = d.createElement(s); js.id = id;
    js.src = "//connect.facebook.net/en_US/sdk.js#xfbml=1&version=v2.7&appId=<: $app_id :>";
    fjs.parentNode.insertBefore(js, fjs);
  }(document, 'script', 'facebook-jssdk'));
  </script>

  <h1>Hello</h1>

  <div class="fb-login-button"
    data-max-rows="1"
    data-size="xlarge"
    data-show-faces="false"
    data-auto-logout-link="false"
    data-scope="email"
    onlogin="checkLoginState();"
    ></div>
</body>
</html>

@@ verify.html.tx

<!doctype html>
<html lang="en">
<head>
</head>
<body>
  <h1>Auth successful?</h1>
  <dl>
    <dt>User ID</dt>
    <dd><: $facebook_account.id :></dd>
    <dt>Email</dt>
    <dd><: $facebook_account.email :></dd>
  </dl>
</body>
</html>
