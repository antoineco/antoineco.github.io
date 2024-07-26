source "https://rubygems.org"

# Although the github-pages Gem has a loose Ruby version requirement[1], we
# would ideally want to use Ruby 2.7 consistently to match GitHub's own Pages
# builder[2]. However, this Ruby version is no longer supported, and therefore
# no longer distributed.
#
# For reference, pinning Nixpkgs to a revision which still includes
# 'rubyPackages_2_7' requires:
#
#   1. Setting a 'permittedInsecurePackages' exception via Nixpkgs for
#      'ruby-2.7.8' and 'openssl-1.1.1w'.
#   2. A very expensive build of numerous packages, including 'llvm' and
#      'ruby', which takes over an hour on an Apple M3 chip.
#
# [1]: https://rubygems.org/gems/github-pages
# [2]: https://github.com/actions/jekyll-build-pages/blob/v1.0.12/Dockerfile
#ruby "~> 2.7.0"

# https://pages.github.com/versions/
group :jekyll_plugins do
  gem "github-pages", "~> 231"
end
