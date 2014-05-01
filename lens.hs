
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}

module L where

import Music.Score
import Music.Score.Util (tripl, untripl, through)
import Music.Score.Convert
import Music.Prelude.Basic
import Data.Maybe
import qualified Data.List as List

{-
  Example:
  
  let s = rcat $ zipWith delay [0,1,2,3] $ repeat(scat [c,d,e] <> delay 4 (scat [e,d]))
  over (extracted.elements odd.phrases.headV) (up _A1) s
-}



-- TODO
-- mvoicePhrases2 :: Iso' (Voice (Maybe a)) (Voice (Maybe (Voice a)))


-- This is the famous voice traversal!
phrasesS :: (Ord (Part a), HasPart' a, Transformable a) => Traversal' (Score a) (Voice a)
phrasesS = extracted . each . singleMVoice . mvoicePhrases . each . _Right

-- More generally:

phrases :: HasVoices a b => Traversal' a (Voice b)
phrases = mvoices . mvoicePhrases . each . _Right


type MVoice a = Voice (Maybe a)

class HasVoices a b | a -> b where
  mvoices :: Traversal' a (MVoice b)
instance HasVoices (MVoice a) a where
  mvoices = id
instance (HasPart' a, Transformable a, Ord (Part a)) => HasVoices (Score a) a where
  mvoices = extracted . each . singleMVoice
  


-- TODO
mvoicePhrases :: Iso' (MVoice a) [Either Duration (Voice a)]
mvoicePhrases = iso mvoiceToPhrases phrasesToMVoice
  where
    phrasesToMVoice :: [Either Duration (Voice a)] -> MVoice a
    phrasesToMVoice = mconcat . fmap (either restToVoice phraseToVoice)

    mvoiceToPhrases :: MVoice a -> [Either Duration (Voice a)]
    mvoiceToPhrases =
      map ( bimap voiceToRest voiceToPhrase 
          . bimap (^.from unsafeEventsV) (^.from unsafeEventsV) ) 
       . groupDiff' (isJust . snd) 
       . view eventsV

      where
    restToVoice :: Duration -> MVoice a
    restToVoice d = stretch d $ pure Nothing

    phraseToVoice :: Voice a -> MVoice a
    phraseToVoice = fmap Just

    voiceToRest :: MVoice a -> Duration
    voiceToRest = sumOf (eventsV.each._1) . fmap (assert "isNothing" isNothing)
    -- TODO just _duration

    voiceToPhrase :: MVoice a -> Voice a
    voiceToPhrase = fmap fromJust

  



-- TODO failure
-- TODO why Transformable?
singleMVoice :: Transformable a => Prism' (Score a) (MVoice a)
singleMVoice = iso scoreToVoice voiceToScore'
  where
    scoreToVoice :: Transformable a => Score a -> MVoice a
    scoreToVoice = (^. voice) . fmap (^. stretched) . fmap throwTime . addRests . (^. events)
        where
           throwTime (t,d,x) = (d,x)
           addRests = concat . snd . List.mapAccumL g 0
               where
                   g u (t, d, x)
                       | u == t    = (t .+^ d, [(t, d, Just x)])
                       | u <  t    = (t .+^ d, [(u, t .-. u, Nothing), (t, d, Just x)])
                       | otherwise = error "addRests: Strange prevTime"

    voiceToScore :: Voice a -> Score a
    voiceToScore = scat . fmap g . (^. stretcheds) where g = (^. getStretched) . fmap return

    voiceToScore' :: MVoice a -> Score a
    voiceToScore' = mcatMaybes . voiceToScore
    

instance Cons (Voice a) (Voice b) a b where
  _Cons = undefined
instance Snoc (Voice a) (Voice b) a b where
  _Snoc = undefined

-- TODO make Voice an instance of Cons/Snoc and remove these
headV :: Transformable a => Traversal' (Voice a) a
headV = (eventsV._head._2)

middleV :: Transformable a => Traversal' (Voice a) a
middleV = (eventsV._middle.traverse._2)

lastV :: Transformable a => Traversal' (Voice a) a
lastV = (eventsV._last._2)

_middle :: (Snoc s s a a, Cons s s b b) => Traversal' s s
-- Traverse writing to all elements *except* first and last
_middle = _tail._init




assert t p x = if p x then x else error ("assertion failed: " ++ t)
        






-- |
-- Group contigous sequences matching/not-matching the predicate.
--
-- >>> groupDiff (== 0) [0,1,2,3,5,0,0,6,7]
-- [[0],[1,2,3,5],[0,0],[6,7]]
--
groupDiff :: (a -> Bool) -> [a] -> [[a]]
groupDiff p []     = []
groupDiff p (x:xs)
  | p x       = (x : List.takeWhile p         xs) : groupDiff p (List.dropWhile p         xs)
  | not (p x) = (x : List.takeWhile (not . p) xs) : groupDiff p (List.dropWhile (not . p) xs)

groupDiff' :: (a -> Bool) -> [a] -> [Either [a] [a]]
groupDiff' p []     = []
groupDiff' p (x:xs)
  | not (p x) = Left  (x : List.takeWhile (not . p) xs) : groupDiff' p (List.dropWhile (not . p) xs)
  | p x       = Right (x : List.takeWhile p         xs) : groupDiff' p (List.dropWhile p         xs)


eventsV :: Lens (Voice a) (Voice b) [(Duration, a)] [(Duration, b)]
eventsV = unsafeEventsV
  --(stretcheds.through (from stretched) (from stretched))

unsafeEventsV :: Iso (Voice a) (Voice b) [(Duration, a)] [(Duration, b)]
unsafeEventsV = iso (map (^.from stretched).(^.stretcheds)) ((^.voice).map (^.stretched))






