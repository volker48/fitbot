{-# LANGUAGE OverloadedStrings, DeriveGeneric #-}

import qualified Web.Scotty as S
import Network.Wai.Middleware.RequestLogger
import qualified Data.Text.Encoding as ES
import qualified Data.Text.Lazy.Encoding as EL
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL
import qualified Data.Text.Lazy as L
import qualified Database.Redis as R
import Control.Monad.IO.Class (liftIO)
import Control.Applicative
import Control.Monad
import Data.Aeson
import Control.Monad (when)
import Data.Monoid (mconcat)
import System.Environment (getEnv)
import GHC.Generics
import System.Random

myConnectInfo :: R.ConnectInfo
myConnectInfo = R.defaultConnectInfo{R.connectHost = "fitbot-redis"}

data SlackResponse = SlackResponse {text :: L.Text} deriving Show

data FitbotQuote = FitbotQuote {quote :: L.Text, author :: L.Text} deriving (Show, Generic)

instance FromJSON FitbotQuote
instance ToJSON FitbotQuote

instance ToJSON SlackResponse where
    toJSON (SlackResponse text) = object ["text" .= text]

type Token = L.Text
type User = L.Text
type Move = L.Text
type Record = L.Text

quoteFile :: FilePath
quoteFile = "quotes.json"

getJSONQuotes :: IO BL.ByteString
getJSONQuotes = BL.readFile quoteFile

main :: IO ()
main = S.scotty 5000 $ do
    S.middleware logStdoutDev
    quotes <- liftIO $ decode <$> getJSONQuotes
    envToken <- liftIO $ L.pack <$> getEnv "FITBOT_TOKEN"
    S.get "/" $ do
        S.html "<h1>Come with me if you want to lift</h1>"
    S.get "/swole" $ do
        S.setHeader "Content-Type" "image/jpg"
        S.file "images/arnold-schwarzenegger.jpg"
    incoming quotes envToken


incoming :: Maybe [FitbotQuote] -> Token  -> S.ScottyM()
incoming quotes envToken = S.post "/incoming" $ do
    userName <- S.param "user_name"
    paramToken <- S.param "token"
    when (userName /= ("slackbot"::L.Text) && paramToken == envToken) $ do
        chatText <- S.param "text"
        conn <- liftIO $ R.connect myConnectInfo
        res <- liftIO $ determineCommand quotes conn userName $ L.words $ L.toLower chatText
        S.json res

determineCommand :: Maybe [FitbotQuote] -> R.Connection -> User -> [L.Text] -> IO SlackResponse
determineCommand _ _ _ ["help"] = return SlackResponse{text = ":boom: FitBot Commands :boom:\nstore {move} {record} - Store a new or replace an old record\nlist {user}\ndelete {move} - Delete a record\n quote - Display a random fitness quote"}
determineCommand _ conn user ("store":move:record) = save conn user move $ L.unwords record
determineCommand _ conn user ("list":_) = list conn user
determineCommand _ conn user ("delete":move:_) = delete conn user move
determineCommand quotes _ _ ("quote":_) = makeQuoteResponse quotes
determineCommand _ _ _ _ = return SlackResponse{text = ""}

makeQuoteResponse :: Maybe [FitbotQuote] -> IO SlackResponse
makeQuoteResponse Nothing = return SlackResponse {text = "Error with quotes."}
makeQuoteResponse (Just quotes) = do
    let quoteToResponse :: FitbotQuote -> SlackResponse
        quoteToResponse (FitbotQuote{quote = q, author = a}) = SlackResponse{text = mconcat [q, "\n\n- ", a]}
    randIndex <- getStdRandom (randomR (0,93))
    return $ quoteToResponse $ (!!) quotes randIndex

fromLazyTextToStrictBS :: L.Text -> BS.ByteString
fromLazyTextToStrictBS = ES.encodeUtf8 . L.toStrict

makeListResponse :: [(BS.ByteString, BS.ByteString)] -> SlackResponse
makeListResponse redisResp = SlackResponse{text = records}
    where records = EL.decodeUtf8 $ BL.fromStrict $ BS.concat $ map (\record -> BS.concat [(fst record), " ", (snd record), "\n"]) redisResp

list :: R.Connection -> User -> IO SlackResponse
list conn user = do
    R.runRedis conn $ do
        let userBS = fromLazyTextToStrictBS user
        reply <- R.hgetall userBS
        case reply of Right records -> return $ makeListResponse records
                      _             -> return SlackResponse{text = "Redis error listing records"}

save :: R.Connection -> User -> Move -> Record -> IO SlackResponse
save conn user move record = do
    R.runRedis conn $ do
        let userBS = fromLazyTextToStrictBS user
            moveBS = fromLazyTextToStrictBS move
            recordBS = fromLazyTextToStrictBS record
        R.hset userBS moveBS recordBS
        return SlackResponse{text = "Record saved"}

delete :: R.Connection -> User -> Move -> IO SlackResponse
delete conn user move = do
    R.runRedis conn $ do
        let moveBS = fromLazyTextToStrictBS move
            userBS = fromLazyTextToStrictBS user
        reply <- R.hdel userBS [moveBS]
        case reply of Right 0 -> return SlackResponse{text = mconcat ["No record for ", move, " for ", user]}
                      _       -> return SlackResponse{text = ":recycle: record delete"}
