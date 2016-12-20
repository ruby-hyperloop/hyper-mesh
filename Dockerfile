FROM ruby

# NOTE https://yarnpkg.com/en/docs/install#linux-tab
RUN curl -sL https://deb.nodesource.com/setup_7.x | bash -
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

RUN apt-get update -qq && apt-get install -y build-essential libpq-dev yarn
RUN yarn global add phantomjs-prebuilt

RUN mkdir /hyper-mesh
WORKDIR /hyper-mesh

ADD Gemfile.lock .
ADD Gemfile .
ADD hyper-mesh.gemspec .
ADD lib/hypermesh/version.rb lib/hypermesh/
RUN bundle install --frozen

ADD . .
