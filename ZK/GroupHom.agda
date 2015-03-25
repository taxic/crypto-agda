{-# OPTIONS --without-K #-}
open import Type using (Type)
open import Function using (flip)
open import Data.Product renaming (proj₁ to fst; proj₂ to snd)
open import Data.Bool.Base using (Bool) renaming (T to ✓)
open import Relation.Binary.PropositionalEquality.NP using (_≡_; _≢_; idp; ap; ap₂; !_; _∙_; module ≡-Reasoning)
open import Algebra.Group
open import Algebra.Group.Homomorphism
import ZK.SigmaProtocol.KnownStatement

module ZK.GroupHom
    {G+ G* : Type} (grp-G+ : Group G+) (grp-G* : Group G*)
    (_==_ : G* → G* → Bool)
    (✓-== : ∀ {x y} → x ≡ y → ✓ (x == y))
    (==-✓ : ∀ {x y} → ✓ (x == y) → x ≡ y)

    (open Additive-Group grp-G+ hiding (_⊗_))
    (open Multiplicative-Group grp-G* hiding (_^_))

    {C D : Type} -- e.g. C ⊆ ℕ, D = C/0
    (_⊗_ : G+ → C → G+)
    (_^_ : G* → C → G*)
    (_−ᶜ_ : C → C → D)
    (1* 1/ : D → C) -- Two ways to go from D to C, 1*d embeds D in C, 1/d does the inverse operation
    (^-−ᶜ  : ∀ {b x y}(x≢y : x ≢ y) → b ^ 1*(x −ᶜ y) ≡ (b ^ x) / (b ^ y))
    (^-^-1/ : ∀ {b x y}(x≢y : x ≢ y) → (b ^ 1*(x −ᶜ y))^(1/(x −ᶜ y)) ≡ b)

    (φ : G+ → G*) -- For instance φ(x) = g^x
    (φ-hom : GroupHomomorphism grp-G+ grp-G* φ)
    (φ-hom-iterated : ∀ {x c} → φ (x ⊗ c) ≡ φ x ^ c)

    (y : G*)
    where

  Commitment = G*
  Challenge  = C
  Response   = G+
  Witness    = G+
  Randomness = G+
  _∈y : Witness → Type
  x ∈y = φ x ≡ y

  open ZK.SigmaProtocol.KnownStatement Commitment Challenge Response Randomness Witness _∈y public

  prover : Prover
  prover a x = φ a , response
     where response : Challenge → Response
           response c = (x ⊗ c) + a

  verifier : Verifier
  verifier (mk A c s) = φ s == ((y ^ c) * A)

  -- We still call it Schnorr since essentially not much changed.
  -- The scheme abstracts away g^ as an homomorphism called φ
  -- and one get to distinguish between the types C vs G+ and
  -- their operations _⊗_ vs _*_.
  Schnorr : Σ-Protocol
  Schnorr = (prover , verifier)

  -- The simulator shows why it is so important for the
  -- challenge to be picked once the commitment is known.
  -- To fake a transcript, the challenge and response can
  -- be arbitrarily chosen. However to be indistinguishable
  -- from a valid proof they need to be picked at random.
  simulator : Simulator
  simulator c s = A
      where
        -- Compute A, such that the verifier accepts!
        A = (y ^ c)⁻¹ * φ s

  -- The extractor shows the importance of never reusing a
  -- commitment. If the prover answers to two different challenges
  -- comming from the same commitment then the knowledge of the
  -- prover (the witness) can be extracted.
  extractor : Extractor verifier
  extractor t² = x'
      module Witness-extractor where
        open Transcript² t² public
          using (verify₀; verify₁; c₀≢c₁)
          renaming ( get-A to A
                   ; get-f₀ to r₀; get-f₁ to r₁
                   ; get-c₀ to c₀; get-c₁ to c₁
                   )
        rd   = r₀ − r₁
        cd   = c₀ −ᶜ c₁
        1/cd = 1/ cd
        x'   = rd ⊗ 1/cd

  open ≡-Reasoning
  open GroupHomomorphism φ-hom

  correct : Correct Schnorr
  correct x a c w
    = ✓-== (φ((x ⊗ c) + a)  ≡⟨ hom ⟩
            φ(x ⊗ c)  * A   ≡⟨ *= φ-hom-iterated idp ⟩
            (φ x ^ c) * A   ≡⟨ ap (λ z → (z ^ c) * A) w ⟩
            (y ^ c)   * A   ∎)
    where
      A = φ a

  shvzk : Special-Honest-Verifier-Zero-Knowledge Schnorr
  shvzk = record { simulator = simulator
                 ; correct-simulator =
                    λ _ _ → ✓-== (! elim-*-!assoc= (snd ⁻¹-inverse)) }

  module _ (t² : Transcript² verifier) where
    open Witness-extractor t²

    φrd≡ycd : _
    φrd≡ycd
      = φ rd                        ≡⟨by-definition⟩
        φ (r₀ − r₁)                 ≡⟨ −-/ ⟩
        φ r₀ / φ r₁                 ≡⟨ /= (==-✓ verify₀) (==-✓ verify₁) ⟩
        (y ^ c₀ * A) / (y ^ c₁ * A) ≡⟨ elim-*-right-/ ⟩
        y ^ c₀ / y ^ c₁             ≡⟨ ! ^-−ᶜ c₀≢c₁ ⟩
        y ^ 1*(c₀ −ᶜ c₁)            ≡⟨by-definition⟩
        y ^ 1* cd                   ∎

    -- The extracted x is correct
    extractor-ok : φ x' ≡ y
    extractor-ok
      = φ(rd ⊗ 1/cd)       ≡⟨ φ-hom-iterated ⟩
        φ rd ^ 1/cd        ≡⟨ ap₂ _^_ φrd≡ycd idp ⟩
        (y ^ 1* cd)^ 1/cd  ≡⟨ ^-^-1/ c₀≢c₁ ⟩
        y                  ∎

  special-soundness : Special-Soundness Schnorr
  special-soundness = record { extractor = extractor
                             ; extract-valid-witness = extractor-ok }

  special-Σ-protocol : Special-Σ-Protocol
  special-Σ-protocol = record { Σ-protocol = Schnorr ; correct = correct ; shvzk = shvzk ; ssound = special-soundness }
-- -}
-- -}
-- -}
-- -}
