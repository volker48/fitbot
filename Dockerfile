FROM haskell:7.8

RUN cabal update

ADD ./fitbot.cabal /opt/fitbot/fitbot.cabal

RUN cd /opt/fitbot && cabal install --only-dependencies -j4

ADD ./src  /opt/fitbot/src/
ADD ./images /opt/fitbot/images/
ADD ./quotes.json /opt/fitbot/quotes.json

RUN cd /opt/fitbot && cabal install

ENV PATH /root/.cabal/bin:$PATH

WORKDIR /opt/fitbot

EXPOSE 5000

CMD ["fitbot"]
