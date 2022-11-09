{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE LambdaCase          #-}
{-# LANGUAGE TypeApplications    #-}

module Notifications.SecretBase
  ( SecretBaseLive (..)
  , getNextNewSecretBase
  ) where

-- Ado Bot modules
import Lenses
import App                               (App)
import App.Types                         (Db (..))
import Notifications.SecretBase.Internal (Lives (..), SecretBaseLive (..))
import Network                           (fetchJson)
import Utils                             ((>>>=))
import Notifications.Utils               (returnWhenFound)
import Notifications.History             (getNotifHistory, changeNotifHistory)

-------------------------------------------------------------------------------

-- | This function only returns once Ado goes live on Secret Base
getNextNewSecretBase :: App SecretBaseLive
getNextNewSecretBase = returnWhenFound latestSecretBase "New Secret Base"

-- | Returns a freshly started Secret Base stream by Ado, or a Left explaining
-- what problem it encountered.
latestSecretBase :: App (Either Text SecretBaseLive)
latestSecretBase = fetchJson @Lives endpoint >>>= \case
  Lives [] -> err "No ongoing live"
  Lives lives -> do
    db <- asks _notifDb
    notifHistory <- getNotifHistory db
    let new = filter ((`notElem` (notifHistory^.secretBase)) . sblUrl) lives
    case listToMaybe new of
      Nothing -> err "Ongoing live found but already notified"
      Just live -> do
        changeNotifHistory db . over secretBase $ \sb -> (live^.url) : take 50 sb

        pure $ Right live
  where
  endpoint = "https://nfc-api.ado-dokidokihimitsukichi-daigakuimo.com/fc/fanclub_sites/95/live_pages?page=1&live_type=1&per_page=1"
  err = pure . Left . ("[Secret Base] " <>)
