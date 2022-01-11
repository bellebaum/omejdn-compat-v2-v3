# frozen_string_literal: true

# Enforce logging output
$stdout.sync = true
$stderr.sync = true

require 'sinatra'
require 'openssl'
require 'json'
require 'jwt'
require 'net/http'

# Different port for easy testing
set :port, 4568
set :bind, '0.0.0.0'

V3_ENDPOINT = ENV['V3_URL']
# We need to re-sign the tokens
SIGNING_KEY = OpenSSL::PKey::RSA.new File.read(ENV['KEY_LOCATION'])

# Retrieve a token, then return the token format to v2
post '/token' do
    target_uri = URI(V3_ENDPOINT+request.path_info)
    res = Net::HTTP.post_form(target_uri, params)
    headers.merge! (res.to_hash.map do |k,v|
        { k.split('-').map(&:capitalize).join('-') => v }
    end).reduce(:merge)

    # Alter the response here
    body = JSON.parse res.body
    at = JWT.decode body['access_token'], SIGNING_KEY.public_key, true, {nbf_leeway:30, algorithm: 'RS256'}
    at[0]['aud'] = at[0]['aud'][0] # `aud` was a String
    at[0]['scopes'] = at[0]['scope'].split # `scopes` was an array
    at[0].delete('scope') # `scope` was called `scopes`
    body['access_token'] = JWT.encode at[0], SIGNING_KEY, 'RS256', at[1]

    halt res.code.to_i, body.to_json
end

# Forward .well-known/*
get '/.well-known/*' do
    params.delete(:splat)
    target_uri = URI(V3_ENDPOINT+request.path_info)
    target_uri.query = URI.encode_www_form(params)
    res = Net::HTTP.get_response(target_uri)
    headers.merge! (res.to_hash.map do |k,v|
        { k.split('-').map(&:capitalize).join('-') => v }
    end).reduce(:merge)
    halt res.code.to_i, res.body
end