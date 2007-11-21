-----------------------------------------------------------------------------
-- |
-- Module      :  Data.DList
-- Copyright   :  (c) Don Stewart 2006-2007
-- License     :  BSD-style (see the file LICENSE)
--
-- Maintainer  :  dons@cse.unsw.edu.au
-- Stability   :  experimental
-- Portability :  portable (Haskell 98)
--
-- Difference lists: a data structure for O(1) append on lists.
--
-----------------------------------------------------------------------------

module Data.DList (

   DList(..)         -- abstract, instance Monoid, Functor, Applicative, Monad, MonadPlus

  -- * Construction
  ,fromList      -- :: [a] -> DList a
  ,toList        -- :: DList a -> [a]

  -- * Basic functions
  ,empty         -- :: DList a
  ,singleton     -- :: a -> DList a
  ,cons          -- :: a -> DList a -> DList a
  ,snoc          -- :: DList a -> a -> DList a
  ,append        -- :: DList a -> DList a -> DList a
  ,concat        -- :: [DList a] -> DList a
  ,list          -- :: b -> (a -> DList a -> b) -> DList a -> b
  ,head          -- :: DList a -> a
  ,tail          -- :: DList a -> DList a
  ,unfoldr       -- :: (b -> Maybe (a, b)) -> b -> DList a
  ,foldr         -- :: (a -> b -> b) -> b -> DList a -> b
  ,map           -- :: (a -> b) -> DList a -> DList b

  -- * MonadPlus
  , maybeReturn

  ) where

import Prelude hiding (concat, foldr, map, head, tail)
import qualified Data.List as List
import Control.Monad
import Control.Applicative(Applicative(..))
import Data.Monoid

-- | A difference list is a function that given a list, returns the
-- original contents of the difference list prepended at the given list
--
-- This structure supports /O(1)/ append and snoc operations on lists,
-- making it very useful for append-heavy uses, such as logging and
-- pretty printing.
--
-- For example, using DList as the state type when printing a tree with
-- the Writer monad
--
-- > import Control.Monad.Writer
-- > import Data.DList
-- > 
-- > data Tree a = Leaf a | Branch (Tree a) (Tree a)
-- >
-- > flatten_writer :: Tree x -> DList x
-- > flatten_writer = snd . runWriter . flatten
-- >     where
-- >       flatten (Leaf x)     = tell (singleton x)
-- >       flatten (Branch x y) = flatten x >> flatten y
--
newtype DList a = DL { unDL :: [a] -> [a] }

-- | Converting a normal list to a dlist
fromList    :: [a] -> DList a
fromList    = DL . (++)
{-# INLINE fromList #-}

-- | Converting a dlist back to a normal list
toList      :: DList a -> [a]
toList      = ($[]) . unDL
{-# INLINE toList #-}

-- | Create a difference list containing no elements
empty       :: DList a
empty       = DL id
{-# INLINE empty #-}

-- | Create difference list with given single element
singleton   :: a -> DList a
singleton   = DL . (:)
{-# INLINE singleton #-}

-- | /O(1)/, Prepend a single element to a difference list
infixr `cons`
cons        :: a -> DList a -> DList a
cons x xs   = DL ((x:) . unDL xs)
{-# INLINE cons #-}

-- | /O(1)/, Append a single element at a difference list
infixl `snoc`
snoc        :: DList a -> a -> DList a
snoc xs x   = DL (unDL xs . (x:))
{-# INLINE snoc #-}

-- | /O(1)/, Appending difference lists
append       :: DList a -> DList a -> DList a
append xs ys = DL (unDL xs . unDL ys)
{-# INLINE append #-}

-- | /O(spine)/, Concatenate difference lists
concat       :: [DList a] -> DList a
concat       = List.foldr append empty
{-# INLINE concat #-}

-- | /O(length dl)/, List elimination, head, tail. 
list :: b -> (a -> DList a -> b) -> DList a -> b
list nill consit dl =
  case toList dl of
    [] -> nill
    (x : xs) -> consit x (fromList xs)

-- | Return the head of the list
head :: DList a -> a
head = list (error "Data.DList.head: empty list") const

-- | Return the tail of the list
tail :: DList a -> DList a
tail = list (error "Data.DList.tail: empty list") (flip const)

-- | Unfoldr for difference lists
unfoldr :: (b -> Maybe (a, b)) -> b -> DList a
unfoldr pf b =
  case pf b of
    Nothing     -> empty
    Just (a, b') -> cons a (unfoldr pf b')

-- | Foldr over difference lists
foldr        :: (a -> b -> b) -> b -> DList a -> b
foldr f b    = List.foldr f b . toList
{-# INLINE foldr #-}

-- | Map over difference lists.
map          :: (a -> b) -> DList a -> DList b
map f        = foldr (cons . f) empty
{-# INLINE map #-}

instance Monoid (DList a) where
    mempty  = empty
    mappend = append

instance Functor DList where
    fmap = map
    {-# INLINE fmap #-}

#if __GLASGOW_HASKELL__ >= 608
instance Applicative DList where
    pure  = return
    (<*>) = ap
#endif

instance Monad DList where
  m >>= k
    -- = concat (toList (fmap k m))
    -- = (concat . toList . fromList . List.map k . toList) m
    -- = concat . List.map k . toList $ m
    -- = List.foldr append empty . List.map k . toList $ m
    -- = List.foldr (append . k) empty . toList $ m
    = foldr (append . k) empty m
  {-# INLINE (>>=) #-}

  return x = singleton x
  {-# INLINE return #-}

  fail _   = empty
  {-# INLINE fail #-}

instance MonadPlus DList where
  mzero    = empty
  mplus    = append

-- Use this to convert Maybe a into DList a, or indeed into any other MonadPlus instance.
maybeReturn :: MonadPlus m => Maybe a -> m a
maybeReturn = maybe mzero return
