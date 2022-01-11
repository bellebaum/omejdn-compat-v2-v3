# DAPS V2 - V3 compatibility script

This is a simple proxy forwarding requests from Omejdn 1.0.2 to later versions,
so that people can ignore standards if they want to.

## Usage

When starting the script using `ruby compat.rb`
(which is what the Docker image does),
make sure that the following environment variables are set:

- **V3_URL**: The URL to forward requests to (not including /token or /.well-known/...)
  - For local setups this is probably `http://localhost:4567`
  - For docker-compose you might want to use e.g. `http://omejdn-container-name:4567`
  - *Does not support TLS out of the box*
- **KEY_LOCATION**: Mount Omejdn's signing key here.

You can now POST to e.g. `http://localhost:4568/token`. The call will be proxied to `V3_URL/token` and the response adapted to look like a V2 DAT.
Calls to `/.well-known/*` are also forwarded, but responses remain unchanged.