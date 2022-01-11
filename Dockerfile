FROM ruby:3
ENV V3_URL="http://localhost:4567"
ENV KEY_LOCATION="/opt/key.pem"

WORKDIR /opt

#Rebuild if Gemfile changed
COPY Gemfile .
COPY Gemfile.lock .
RUN bundle install

COPY compat.rb .

EXPOSE 4568

CMD [ "ruby", "compat.rb" ]
