# Jekyll Blog

Theme based on [Long Haul](http://github.com/brianmaierjr/long-haul), by [@brianmaierjr](https://twitter.com/brianmaierjr).

## Run

Inside a Docker container:

```console
$ docker run --rm \
  -v $PWD:/srv/jekyll \
  -p 4000:4000 \
  jekyll/jekyll \
    jekyll serve --drafts
```

## Compile CSS files

It is necessary to re-compile CSS files inside `assets/css/` after every modification to SCSS assets.

Required dependencies:
* `node` (>=v13.0.0)
* `ruby`, `ruby-dev` (>=2.3.0)

Steps:
1. `gem install bundler`
2. `bundle install`
3. `npm install`
4. `bundle exec npx gulp sass` (or `bundle exec $(npm bin)/gulp sass`)
