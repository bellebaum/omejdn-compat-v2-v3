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

    body = JSON.parse res.body
    if res.code[0] == '2'
        # Alter the response here
        at = JWT.decode body['access_token'], SIGNING_KEY.public_key, true, {nbf_leeway:30, algorithm: 'RS256'}
        at[0]['aud'] = at[0]['aud'][0] # `aud` was a String
        at[0]['scopes'] = at[0]['scope'].split # `scopes` was an array
        at[0].delete('scope') # `scope` was called `scopes`
        body['access_token'] = JWT.encode at[0], SIGNING_KEY, 'RS256', at[1]
    end

    halt res.code.to_i, body.to_json
end

def self.sign_metadata(metadata)
    to_sign = metadata.merge
    to_sign['iss'] = to_sign['issuer']
    signing_material = Server.load_skey('token')
    JWT.encode to_sign, SIGNING_KEY, 'RS256', { kid: kid }
end

# Forward .well-known/*
get '/.well-known/*' do
    url = params.delete(:splat)[0]
    target_uri = URI(V3_ENDPOINT+request.path_info)
    target_uri.query = URI.encode_www_form(params)
    res = Net::HTTP.get_response(target_uri)
    headers.merge! (res.to_hash.map do |k,v|
        { k.split('-').map(&:capitalize).join('-') => v }
    end).reduce(:merge)

    body = res.body
    if res.code[0] == '2'
        body = body.gsub('/v3/','/v2/')
        # For openid metadata, resign the metadata
        if ['openid-configuration', 'oauth-authorization-server'].include? url
            json = JSON.parse body
            # Hide a few endpoints
            ['authorization', 'pushed_authorization_request', 'userinfo'].each do |ep|
                json.delete("#{ep}_endpoint")
            end
            jwt = JWT.decode json.delete('signed_metadata'), SIGNING_KEY.public_key, true, {nbf_leeway:30, algorithm: 'RS256'}
            json['signed_metadata'] = JWT.encode json, SIGNING_KEY, 'RS256', { kid: jwt[1]['kid'] }
            body = json.to_json
        end
    end

    halt res.code.to_i, body
end

# For convenience, re-implement /about
get '/about' do
    headers['Content-Type'] = 'application/json'
    halt 200, { 'version'=> 'v2-v3-compat', 'license' => 'Apache2.0' }.to_json
end
