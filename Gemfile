source "https://rubygems.org"

# Pin to the same Jekyll major that GitHub Pages ships, so what we see
# locally matches what HHAI-5108's deploy workflow renders. Override
# locally with `bundle config set --local path 'vendor/bundle'`.
gem "jekyll", "~> 4.3"

group :jekyll_plugins do
  gem "jekyll-seo-tag", "~> 2.8"
  gem "jekyll-sitemap", "~> 1.4"
end

# csv was unbundled from the Ruby stdlib in 3.4 — Jekyll still pulls it
# transitively. webrick is needed for `jekyll serve` on Ruby 3.x.
gem "webrick", "~> 1.8"
gem "csv", "~> 3.3"
