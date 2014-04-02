
module Main where

{-
  This simple example shows how to construct a 4-part canon.
-}
import Music.Prelude.Basic

frere  = times 2 (scat [c,d,e,c]^/4) 
      |> times 2 (scat [e,f,g^*2]^/4) 
      |> times 2 (scat [g,a,g,f,scat [e,c]^*2]^/8)
      |> times 2 (scat [c,g_,c^*2]^/4)

frere2 = delay 2 frere </> frere
frere4 = delay 4 frere2 </> frere2

info = title "Frere Jaques" . tempo (metronome (1/4) 120)
main = open $ info $ asScore $ frere4

