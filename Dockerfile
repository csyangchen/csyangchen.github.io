FROM jekyll/jekyll
ADD Gemfile Gemfile
RUN bundle install