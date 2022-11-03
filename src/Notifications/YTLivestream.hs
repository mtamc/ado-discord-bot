{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE ViewPatterns        #-}

module Notifications.YTLivestream (VideoId, getNextNewLivestream) where

-- Ado Bot modules
import Json                ((?.), (?!!), unStr)
import Utils               (betweenSubstrs)
import Notifications.Utils (returnWhenFound)
import Notifications.History
  ( NotifHistoryDb (..)
  , getNotifHistory
  , changeNotifHistory
  )

-- Downloaded libraries
import Data.Acid  (AcidState)
import Data.Aeson (Value (..), decode)
import Network.HTTP.Simple
  ( parseRequest
  , getResponseStatusCode
  , getResponseBody
  , httpBS
  , setRequestHeader
  )
import qualified Data.Text.Lazy.Encoding    as Lazy.Encoding
import qualified Data.ByteString.Lazy.Char8 as L8

-------------------------------------------------------------------------------

type VideoId = Text

-- | This function only returns once Ado goes live on YouTube
getNextNewLivestream :: MonadIO m => AcidState NotifHistoryDb -> m VideoId
getNextNewLivestream = returnWhenFound newLivestream "New livestream"

-- | Returns the video ID of Ado's just-started livestream, or a Left explaining
-- what problem it encountered.
newLivestream :: MonadIO m => AcidState NotifHistoryDb -> m (Either Text VideoId)
newLivestream db = do
  request <- liftIO $ parseRequest "GET https://www.youtube.com/c/Ado1024"
  response <- httpBS . setRequestHeader "Accept-Language" ["en"] $ request

  let status  = getResponseStatusCode response
      jsonStr = getPayload . decodeUtf8 $ getResponseBody response

  case (status, jsonStr) of
    (200, Just payload) ->
      case decode payload :: Maybe Value of
        Just (extract -> Right vidId) -> do
          notifHistory <- getNotifHistory db
          if vidId `notElem` notifHistory.ytStream then do
            changeNotifHistory db
              (\hist -> hist { ytStream = vidId : take 50 hist.ytStream })

            pure $ Right vidId

          else err "Found livestream already notified"

        Just (extract -> Left NotLive) -> err "Found stream but not live yet"
        Just (extract -> Left e)       -> err $ "Failed to extract: " <> show e
        _                              -> err "Found JSON but failed to decode"

    (200, Nothing) -> err "No ongoing live"
    _              -> err "Non-200 status code"

  where
  err  = pure . Left . ("[Livestream] " <>)

-- | Takes the page source, returns only the embedded JSON of the first
-- livestream as ByteString
getPayload :: Text -> Maybe L8.ByteString
getPayload = fmap (Lazy.Encoding.encodeUtf8 . fromStrict)
  . betweenSubstrs "[{\"videoRenderer\":" "}]}}],\"trackingParams\""

data LivestreamExtractionError = NotLive | OtherError Text deriving (Show)

extract :: Value -> Either LivestreamExtractionError Text
extract ytData = do
  videoId <- pure ytData ?. "videoId" >>= unStr & first OtherError

  let isLive =
        pure ytData
          ?. "thumbnailOverlays" ?!! 0
          ?. "thumbnailOverlayTimeStatusRenderer"
          ?. "style"
          >>= unStr

  case isLive of
    Right "LIVE" -> pure videoId
    _            -> Left NotLive