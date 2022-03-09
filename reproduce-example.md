Reproduce issues in servarr/mediawiki

```
$ docker run -p 127.0.0.1:8080:80 servarr/mediawiki:1.0.7
$ wget 127.0.0.1:8080/extensions/MW-OAuth2Client/vendors/oauth2-client/vendor/phpunit/phpunit/src/Util/PHP/eval-stdin.php
```
