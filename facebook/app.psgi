use strict;
use warnings;
use Data::Dumper;
use HTTP::Request::Common;
use LWP::UserAgent;
use Mojo::JSON;
use Mojolicious::Lite;
use URI;

my $app_id     = $ENV{APP_ID};

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
        my $c = shift;
        my $params = $c->req->params->to_hash;
        my $user_id      = $params->{user_id};
        my $access_token = $params->{access_token};

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
                + "&user_id="
                + encodeURIComponent(response.authResponse.userID);
        }
        else {
            console.log('NOT connected');
        }
    });
  }

  window.fbAsyncInit = function () {
    checkLoginState();
  };

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
