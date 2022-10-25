{-# LANGUAGE OverloadedStrings #-}

module Network (fetchJson) where

-- Downloaded libraries
import Data.Aeson (Value (..))
import Network.HTTP.Simple
  ( httpJSONEither
  , JSONException
  , Request
  , getResponseBody
  , getResponseStatusCode
  )

-------------------------------------------------------------------------------

fetchJson :: MonadIO m => Text -> (Value -> Either Text b) -> Request -> m (Either Text b)
fetchJson context parser request = do
  resp <- httpJSONEither request

  let json :: Either JSONException Value
      json   = getResponseBody resp
      status = getResponseStatusCode resp
      err = pure . Left . (("[" <> context <> "] ") <>)

  case (status, json) of
    (200, Right value) -> pure $ parser value
    (200, _) -> err "Failed to decode JSON"
    (code, resp') -> err (show code <> ": " <> show resp')