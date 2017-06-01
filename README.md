# Fitbot

Fitbot is a Slackbot that will store a user's personal best fitness 
record. Its currently being used to store records like max
push ups, etc. You could use it to store any records though.

## Deploying.

If you want to run your own Fitbot you will need to setup a Slack outgoing web hook that will send requests to your Fitbot server.

To run your own Fitbot you just need to use Docker and specify your `FITBOT_TOKEN` environment variable and run a named Redis container as well.

    sudo docker run -e FITBOT_TOKEN=yourtoken -d -p 5000:5000  --name fitbot --link fitbot-redis:fitbot-redis volker48/fitbot

This is assuming you are already running a redis container named `fitbot-redis`. The token is used to verify that the
request is coming from your Slack integration.
