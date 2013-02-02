open import Type
open import Data.Bits
open import Data.Product

module Game.EntropySmoothing
  (M    : ★)        -- Message
  (Hash : ★)
  (ℋ   : M → Hash) -- Hashing function
  (Rₐ   : ★)        -- Adversary randomness
  where

  -- Entropy smoothing adversary
  Adv : ★
  Adv = Rₐ → Hash → Bit

  -- The randomness supply needed for the entropy
  -- smoothing games
  R : ★
  R = M × Hash × Rₐ

  -- Entropy smoothing game:
  --   * take an adversary
  --   * take the randomness supply
  --   * output from the adversary:
  --       * 0: output from ℋ
  --       * 1: random-hash
  Game : ★
  Game = Adv → R → Bit

  -- In this game we always use ℋ on a random message
  ⅁₀ : Game
  ⅁₀ A (m , _ , rₐ) = A rₐ (ℋ m)

  -- In this game we just retrun a random Hash value
  ⅁₁ : Game
  ⅁₁ A (_ , h , rₐ) = A rₐ h

  -- Package the two previous games
  ⅁ : Bit → Game
  ⅁ = proj (⅁₀ , ⅁₁)
