{-# LANGUAGE OverloadedRecordDot #-}

module DiscordBot.Perms (PermLvl (..), getPermLvl) where

-- Ado Bot modules
import BotConfig                  (botConfig, BotConfig (..))
import DiscordBot.Guilds.Settings (GuildSettings (..), w64)

-- Downloaded libraries
import Discord.Types
  ( GuildMember (..)
  , User (..)
  , DiscordId (..)
  , Snowflake (..)
  )

-------------------------------------------------------------------------------

data PermLvl
  = PermLvlUser
  | PermLvlBotManager
  | PermLvlBotOwner
  deriving (Eq, Ord, Show)

getPermLvl :: GuildSettings -> GuildMember -> PermLvl
getPermLvl g member
  | isBotOwner member     = PermLvlBotOwner
  | isBotManager g member = PermLvlBotManager
  | otherwise             = PermLvlUser

isBotOwner :: GuildMember -> Bool
isBotOwner member = memberId == ownerId where
  memberId = member.memberUser <&> userId
  ownerId  = Just . DiscordId $ Snowflake botConfig.ownerUserId

isBotManager :: GuildSettings -> GuildMember -> Bool
isBotManager g member = maybe False (`elem` rolesOfMember) g.modRole where
  rolesOfMember = member.memberRoles <&> w64
