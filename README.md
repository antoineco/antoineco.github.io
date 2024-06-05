# Personal Web Page

Source of the web page served at <https://acotten.com>.

## License

This work is dual-licensed under Creative Commons Attribution 4.0 International and ISC.

The content of pages and articles—which includes texts, media and code snippets—is covered by [Creative Commons
Attribution 4.0 International License][cc-by-4.0], unless otherwise specified.

The [Bay theme][bay] for Jekyll—which this website is based on—was created by [Eliott Vincent][eliottvincent], and is
covered by [ISC][isc].

`SPDX-License-Identifier: Creative Commons Attribution 4.0 International AND ISC`

[bay]: https://github.com/eliottvincent/bay
[eliottvincent]: https://github.com/eliottvincent

[isc]: https://www.isc.org/licenses/
[cc-by-4.0]: https://creativecommons.org/licenses/by/4.0/

## Serving Locally

Using the Docker image from [actions/jekyll-build-pages][gh-build]:

```sh
echo "$GITHUB_TOKEN" | docker login ghcr.io --username "$GITHUB_USER" --password-stdin
```

```sh
docker container run -i --rm \
  -w /workspace -v "$PWD":/workspace \
  -p 4000:4000 \
  --entrypoint=bundle \
  ghcr.io/actions/jekyll-build-pages:v1.0.12 exec jekyll serve -H 0.0.0.0 --drafts
```

[gh-build]: https://github.com/actions/jekyll-build-pages
