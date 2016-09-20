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

sub app_access_token {
    my $uri = URI->new("https://graph.facebook.com/oauth/access_token");
    $uri->query_form(
        {   client_id     => $app_id,
            client_secret => $app_secret,
            grant_type    => 'client_credentials',
        }
    );

    my $ua  = LWP::UserAgent->new;
    my $res = $ua->request(GET $uri->as_string);

    my %data = do {
        my $response_uri = URI->new;
        $response_uri->query($res->content);
        $response_uri->query_form;
    };

    $data{access_token} or die "Failed fetching app_access_token";
}

sub verify_access_token {
    my $input_token = shift;

    my $uri = URI->new("https://graph.facebook.com/debug_token");
    $uri->query_form(
        {   input_token  => $input_token,
            access_token => app_access_token(),
        }
    );

    my $ua   = LWP::UserAgent->new;
    my $res  = $ua->request(GET $uri->as_string);
    my $data = Mojo::JSON::decode_json($res->content);

    $data->{data}{app_id} eq $app_id;
}

$routes->get('/verify')->name('verify')->to(
    cb => sub {
        my $c            = shift;
        my $params       = $c->req->params->to_hash;
        my $user_id      = $params->{user_id};
        my $access_token = $params->{access_token};

        VERIFY: {
            verify_access_token($access_token)
                or die "Failed fetching debug_token";
        }

        my $uri = URI->new('https://graph.facebook.com');
        $uri->path("/v2.7/${user_id}");
        $uri->query_form(
            {   fields       => 'email',
                access_token => $access_token,
            }
        );

        my $res              = LWP::UserAgent->new->request(GET $uri->as_string);
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
