# Reproduce issues in Figure 1: servarr/mediawiki

```
$ docker run -p 127.0.0.1:8080:80 servarr/mediawiki:1.0.7
$ wget 127.0.0.1:8080/extensions/MW-OAuth2Client/vendors/oauth2-client/vendor/phpunit/phpunit/src/Util/PHP/eval-stdin.php
```

Vulnerable phpunit with `eval-stdin.php` was installed to `oauth2-client` in the history: https://github.com/thephpleague/oauth2-client/commit/22c3cb78834fd508e2270592d8fd1afa78ecb724.

# Reproduce issues in Figure 2: vulfocus/drupal-cve_2019_6340

```
$ docker run -p 127.0.0.1:8080:80 vulfocus/drupal-cve_2019_6340
$ wget 127.0.0.1:8080/core/modules/system/tests/fixtures/update/drupal-8.6.0-minimal-with-warm-caches.sql.gz

File names are shortened to save space in both figures.
