{-# LANGUAGE DeriveDataTypeable, TypeFamilies, StandaloneDeriving #-}
module Main (main) where

import Data.State.Acid.Core
import Data.State.Acid

import qualified Control.Monad.State as State
import Control.Monad.Reader
import Control.Applicative
import System.Environment
import System.IO
import Data.Binary

import Data.Typeable

import qualified Data.Map as Map

------------------------------------------------------
-- The Haskell structure that we want to encapsulate

type Key = String
type Value = String

data KeyValue = KeyValue !(Map.Map Key Value)
    deriving (Typeable)


------------------------------------------------------
-- The transaction we will execute over the state.

insertKey :: Key -> Value -> Update KeyValue ()
insertKey key value
    = do KeyValue m <- State.get
         State.put (KeyValue (Map.insert key value m))

lookupKey :: Key -> Query KeyValue (Maybe Value)
lookupKey key
    = do KeyValue m <- ask
         return (Map.lookup key m)

------------------------------------------------------
-- This is how AcidState is used:

main :: IO ()
main = do acid <- mkAcidState myEvents (KeyValue Map.empty)
          args <- getArgs
          case args of
            [key]
              -> do mbKey <- query acid (LookupKey key)
                    case mbKey of
                      Nothing    -> putStrLn $ key ++ " has no associated value."
                      Just value -> putStrLn $ key ++ " = " ++ value
            [key,val]
              -> do update acid (InsertKey key val)
                    putStrLn "Done."
            _ -> do putStrLn "Usage:"
                    putStrLn "  key          Lookup the value of 'key'."
                    putStrLn "  key value    Set the value of 'key' to 'value'."
          closeAcidState acid



------------------------------------------------------
-- The gritty details. These things may be done with
-- Template Haskell in the future.

data InsertKey = InsertKey Key Value
data LookupKey = LookupKey Key


deriving instance Typeable InsertKey
instance Binary InsertKey where
    put (InsertKey key value) = put key >> put value
    get = InsertKey <$> get <*> get
instance Method InsertKey where
    type MethodResult InsertKey = ()
instance UpdateEvent InsertKey

deriving instance Typeable LookupKey
instance Binary LookupKey where
    put (LookupKey key) = put key
    get = LookupKey <$> get
instance Method LookupKey where
    type MethodResult LookupKey = Maybe Value
instance QueryEvent LookupKey

instance Binary KeyValue where
    put (KeyValue state) = put state
    get = liftM KeyValue get

myEvents :: [Event KeyValue]
myEvents = [ UpdateEvent (\(InsertKey key value) -> insertKey key value)
           , QueryEvent (\(LookupKey key) -> lookupKey key)
           ]
