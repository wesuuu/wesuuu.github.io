FROM ruby:latest

# install jekyll
RUN apt-get update
RUN apt-get install ruby-full build-essential zlib1g-dev -y
RUN gem install jekyll bundler

# create the user/workdir
RUN useradd -u 1000 -m wesley
WORKDIR /home/wesley
COPY . .
RUN bundle install
USER wesley

