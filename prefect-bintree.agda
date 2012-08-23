module prefect-bintree where

import Level as L
open import Function.NP
import Data.Nat.NP as Nat
open Nat using (ℕ; zero; suc; 2^_; _+_; module ℕ°; module ℕ≤)
open import Data.Bool
open import Data.Sum hiding (map)
open import Data.Bits
open import Data.Unit using (⊤)
open import Data.Product using (_×_; _,_; proj₁; proj₂; ∃; uncurry) renaming (swap to swap-×)
open import Data.Vec.NP using (Vec; _++_; module Alternative-Reverse)
open import Relation.Nullary
open import Relation.Binary
import Relation.Binary.PropositionalEquality.NP as ≡
open ≡ using (_≡_; _≢_; _≗_; module ≡-Reasoning)
open import Algebra.FunctionProperties
import Relation.Binary.ToNat as ToNat
open Alternative-Reverse

data Tree {a} (A : Set a) : ℕ → Set a where
  leaf : (x : A) → Tree A zero
  fork : ∀ {n} (left right : Tree A n) → Tree A (suc n)

fromFun : ∀ {n a} {A : Set a} → (Bits n → A) → Tree A n
fromFun {zero} f = leaf (f [])
fromFun {suc n} f = fork (fromFun (f ∘ 0∷_)) (fromFun (f ∘ 1∷_))

toFun : ∀ {n a} {A : Set a} → Tree A n → Bits n → A
toFun (leaf x) _ = x
toFun (fork left right) (b ∷ bs) = toFun (if b then right else left) bs

toFun∘fromFun : ∀ {n a} {A : Set a} (f : Bits n → A) → toFun (fromFun f) ≗ f
toFun∘fromFun {zero}  f [] = ≡.refl
toFun∘fromFun {suc n} f (false ∷ xs)
  rewrite toFun∘fromFun (f ∘ 0∷_) xs = ≡.refl
toFun∘fromFun {suc n} f (true ∷ xs)
  rewrite toFun∘fromFun (f ∘ 1∷_) xs = ≡.refl

fromFun∘toFun : ∀ {n a} {A : Set a} (t : Tree A n) → fromFun (toFun t) ≡ t
fromFun∘toFun (leaf x) = ≡.refl
fromFun∘toFun (fork t₀ t₁)
  rewrite fromFun∘toFun t₀
        | fromFun∘toFun t₁ = ≡.refl

toFun→fromFun : ∀ {n a} {A : Set a} (t : Tree A n) (f : Bits n → A) → toFun t ≗ f → t ≡ fromFun f
toFun→fromFun (leaf x) f t≗f = ≡.cong leaf (t≗f [])
toFun→fromFun (fork t₀ t₁) f t≗f
  rewrite toFun→fromFun t₀ _ (t≗f ∘ 0∷_)
        | toFun→fromFun t₁ _ (t≗f ∘ 1∷_) = ≡.refl

fromFun→toFun : ∀ {n a} {A : Set a} (t : Tree A n) (f : Bits n → A) → t ≡ fromFun f → toFun t ≗ f
fromFun→toFun ._ _ ≡.refl = toFun∘fromFun _

fromFun-≗ : ∀ {n a} {A : Set a} {f g : Bits n → A} → f ≗ g → fromFun f ≡ fromFun g
fromFun-≗ {zero}  f≗g
  rewrite f≗g [] = ≡.refl
fromFun-≗ {suc n} f≗g
  rewrite fromFun-≗ (f≗g ∘ 0∷_)
        | fromFun-≗ (f≗g ∘ 1∷_)
        = ≡.refl

lookup : ∀ {n a} {A : Set a} → Bits n → Tree A n → A
lookup = flip toFun

private
  module Dummy {a} {A : Set a} where
    lft : ∀ {n} → Tree A (1 + n) → Tree A n
    lft (fork t _) = t

    rght : ∀ {n} → Tree A (1 + n) → Tree A n
    rght (fork _ t) = t

    ηfork : ∀ {n} (t : Tree A (1 + n)) → t ≡ fork (lft t) (rght t)
    ηfork (fork _ _) = ≡.refl

    from-× : A × A → Tree A 1
    from-× (x , y) = fork (leaf x) (leaf y)

    to-× : Tree A 1 → A × A
    to-× (fork (leaf x) (leaf y)) = x , y

    swap : ∀ {n} → Tree A (1 + n) → Tree A (1 + n)
    swap t = fork (rght t) (lft t)

    map-inner : ∀ {n} → (Tree A (1 + n) → Tree A (1 + n)) → (Tree A (2 + n) → Tree A (2 + n))
    map-inner f (fork (fork t₀ t₁) (fork t₂ t₃)) =
      case f (fork t₁ t₂) of λ { (fork t₄ t₅) → fork (fork t₀ t₄) (fork t₅ t₃) }

    map-outer : ∀ {n} → (f g : Tree A n → Tree A n) → (Tree A (1 + n) → Tree A (1 + n))
    map-outer f g (fork t u) = fork (f t) (g u)

    interchange : ∀ {n} → Tree A (2 + n) → Tree A (2 + n)
    interchange = map-inner swap

    inner : ∀ {n} → Tree A (2 + n) → Tree A (1 + n)
    inner t = fork (rght (lft t)) (lft (rght t))
open Dummy public

module Fold {a b i} {I : Set i} (ze : I) (su : I → I)
            {A : Set a} {B : I → Set b}
            (f : A → B ze) (_·_ : ∀ {n} → B n → B n → B (su n)) where

  `_ : ℕ → I
  `_ = Nat.fold ze su

  fold : ∀ {n} → Tree A n → B(` n)
  fold (leaf x)    = f x
  fold (fork t₀ t₁) = fold t₀ · fold t₁

fold : ∀ {n a} {A : Set a} (op : A → A → A) → Tree A n → A
fold {A = A} op = Fold.fold 0 suc {B = const A} id op

search≡fold∘fromFun : ∀ {n a} {A : Set a} op (f : Bits n → A) → search op f ≡ fold op (fromFun f)
search≡fold∘fromFun {zero}  op f = ≡.refl
search≡fold∘fromFun {suc n} op f
  rewrite search≡fold∘fromFun op (f ∘ 0∷_)
        | search≡fold∘fromFun op (f ∘ 1∷_) = ≡.refl

-- Returns the flat vector of leaves underlying the perfect binary tree.
toVec : ∀ {n a} {A : Set a} → Tree A n → Vec A (2^ n)
toVec (leaf x)     = x ∷ []
toVec (fork t₀ t₁) = toVec t₀ ++ toVec t₁

lookup' : ∀ {m n a} {A : Set a} → Bits m → Tree A (m + n) → Tree A n
lookup' [] t = t
lookup' (b ∷ bs) (fork t t₁) = lookup' bs (if b then t₁ else t)


update' : ∀ {m n a} {A : Set a} → Bits m → Tree A n → Tree A (m + n) → Tree A (m + n)
update' [] val tree = val
update' (b ∷ key) val (fork tree tree₁) = if b then fork tree (update' key val tree₁)
                                               else fork (update' key val tree) tree₁

map : ∀ {n a b} {A : Set a} {B : Set b} → (A → B) → Tree A n → Tree B n
map f (leaf x) = leaf (f x)
map f (fork t₀ t₁) = fork (map f t₀) (map f t₁)

open import Relation.Binary
open import Data.Star using (Star; ε; _◅_)

data Swp {a} {A : Set a} : ∀ {n} (left right : Tree A n) → Set a where
  left : ∀ {n} {left₀ left₁ right : Tree A n} →
         Swp left₀ left₁ →
         Swp (fork left₀ right) (fork left₁ right)
  right : ∀ {n} {left right₀ right₁ : Tree A n} →
         Swp right₀ right₁ →
         Swp (fork left right₀) (fork left right₁)
  swp₁ : ∀ {n} {left right : Tree A n} →
         Swp (fork left right) (fork right left)
  swp₂ : ∀ {n} {t₀₀ t₀₁ t₁₀ t₁₁ : Tree A n} →
         Swp (fork (fork t₀₀ t₀₁) (fork t₁₀ t₁₁)) (fork (fork t₁₁ t₀₁) (fork t₁₀ t₀₀))

Swp★ : ∀ {n a} {A : Set a} (left right : Tree A n) → Set a
Swp★ = Star Swp

Swp-sym : ∀ {n a} {A : Set a} → Symmetric (Swp {A = A} {n})
Swp-sym (left s)  = left (Swp-sym s)
Swp-sym (right s) = right (Swp-sym s)
Swp-sym swp₁      = swp₁
Swp-sym swp₂      = swp₂

module Rot where
    data Rot {a} {A : Set a} : ∀ {n} (left right : Tree A n) → Set a where
      leaf : ∀ x → Rot (leaf x) (leaf x)
      fork : ∀ {n} {left₀ left₁ right₀ right₁ : Tree A n} →
             Rot left₀ left₁ →
             Rot right₀ right₁ →
             Rot (fork left₀ right₀) (fork left₁ right₁)
      krof : ∀ {n} {left₀ left₁ right₀ right₁ : Tree A n} →
             Rot left₀ right₁ →
             Rot right₀ left₁ →
             Rot (fork left₀ right₀) (fork left₁ right₁)

    Rot-refl : ∀ {n a} {A : Set a} → Reflexive (Rot {A = A} {n})
    Rot-refl {x = leaf x} = leaf x
    Rot-refl {x = fork _ _} = fork Rot-refl Rot-refl

    Rot-sym : ∀ {n a} {A : Set a} → Symmetric (Rot {A = A} {n})
    Rot-sym (leaf x) = leaf x
    Rot-sym (fork p₀ p₁) = fork (Rot-sym p₀) (Rot-sym p₁)
    Rot-sym (krof p₀ p₁) = krof (Rot-sym p₁) (Rot-sym p₀)

    Rot-trans : ∀ {n a} {A : Set a} → Transitive (Rot {A = A} {n})
    Rot-trans (leaf x) q = q
    Rot-trans (fork p₀ p₁) (fork q₀ q₁) = fork (Rot-trans p₀ q₀) (Rot-trans p₁ q₁)
    Rot-trans (fork p₀ p₁) (krof q₀ q₁) = krof (Rot-trans p₀ q₀) (Rot-trans p₁ q₁)
    Rot-trans (krof p₀ p₁) (fork q₀ q₁) = krof (Rot-trans p₀ q₁) (Rot-trans p₁ q₀)
    Rot-trans (krof p₀ p₁) (krof q₀ q₁) = fork (Rot-trans p₀ q₁) (Rot-trans p₁ q₀)

module SwpOp where
    data SwpOp : ℕ → Set where
      ε : ∀ {n} → SwpOp n

      _⁏_ : ∀ {n} → SwpOp n → SwpOp n → SwpOp n

      first : ∀ {n} → SwpOp n → SwpOp (suc n)

      swp : ∀ {n} → SwpOp (suc n)

      swp-seconds : ∀ {n} → SwpOp (2 + n)

    data Perm {a} {A : Set a} : ∀ {n} (left right : Tree A n) → Set a where
      ε : ∀ {n} {t : Tree A n} → Perm t t

      _⁏_ : ∀ {n} {t u v : Tree A n} → Perm t u → Perm u v → Perm t v

      first : ∀ {n} {tA tB tC : Tree A n} →
             Perm tA tB →
             Perm (fork tA tC) (fork tB tC)

      swp : ∀ {n} {tA tB : Tree A n} →
             Perm (fork tA tB) (fork tB tA)

      swp-seconds : ∀ {n} {tA tB tC tD : Tree A n} →
                     Perm (fork (fork tA tB) (fork tC tD))
                              (fork (fork tA tD) (fork tC tB))

    data Perm0↔ {a} {A : Set a} : ∀ {n} (left right : Tree A n) → Set a where
      ε : ∀ {n} {t : Tree A n} → Perm0↔ t t

      swp : ∀ {n} {tA tB : Tree A n} →
             Perm0↔ (fork tA tB) (fork tB tA)

      first : ∀ {n} {tA tB tC : Tree A n} →
             Perm0↔ tA tB →
             Perm0↔ (fork tA tC) (fork tB tC)

      firsts : ∀ {n} {tA tB tC tD tE tF : Tree A n} →
                     Perm0↔ (fork tA tC) (fork tE tF) →
                     Perm0↔ (fork (fork tA tB) (fork tC tD))
                              (fork (fork tE tB) (fork tF tD))

      extremes : ∀ {n} {tA tB tC tD tE tF : Tree A n} →
                     Perm0↔ (fork tA tD) (fork tE tF) →
                     Perm0↔ (fork (fork tA tB) (fork tC tD))
                              (fork (fork tE tB) (fork tC tF))

    -- Star Perm0↔ can then model any permutation

    infixr 1 _⁏_

    second-perm : ∀ {a} {A : Set a} {n} {left right₀ right₁ : Tree A n} →
               Perm right₀ right₁ →
               Perm (fork left right₀) (fork left right₁)
    second-perm f = swp ⁏ first f ⁏ swp

    second-swpop : ∀ {n} → SwpOp n → SwpOp (suc n)
    second-swpop f = swp ⁏ first f ⁏ swp

    <_×_>-perm : ∀ {a} {A : Set a} {n} {left₀ right₀ left₁ right₁ : Tree A n} →
               Perm left₀ left₁ →
               Perm right₀ right₁ →
               Perm (fork left₀ right₀) (fork left₁ right₁)
    < f × g >-perm = first f ⁏ second-perm g

    swp₂-perm : ∀ {a n} {A : Set a} {t₀₀ t₀₁ t₁₀ t₁₁ : Tree A n} →
              Perm (fork (fork t₀₀ t₀₁) (fork t₁₀ t₁₁)) (fork (fork t₁₁ t₀₁) (fork t₁₀ t₀₀))
    swp₂-perm = first swp ⁏ swp-seconds ⁏ first swp

    swp₃-perm : ∀ {a n} {A : Set a} {t₀₀ t₀₁ t₁₀ t₁₁ : Tree A n} →
             Perm (fork (fork t₀₀ t₀₁) (fork t₁₀ t₁₁)) (fork (fork t₀₀ t₁₀) (fork t₀₁ t₁₁))
    swp₃-perm = second-perm swp ⁏ swp-seconds ⁏ second-perm swp

    swp-firsts-perm : ∀ {n a} {A : Set a} {tA tB tC tD : Tree A n} →
                     Perm (fork (fork tA tB) (fork tC tD))
                              (fork (fork tC tB) (fork tA tD))
    swp-firsts-perm = < swp × swp >-perm ⁏ swp-seconds ⁏ < swp × swp >-perm

    Swp⇒Perm : ∀ {n a} {A : Set a} → Swp {a} {A} {n} ⇒ Perm {n = n}
    Swp⇒Perm (left pf) = first (Swp⇒Perm pf)
    Swp⇒Perm (right pf) = second-perm (Swp⇒Perm pf)
    Swp⇒Perm swp₁ = swp
    Swp⇒Perm swp₂ = swp₂-perm

    Swp★⇒Perm : ∀ {n a} {A : Set a} → Swp★ {n} {a} {A} ⇒ Perm {n = n}
    Swp★⇒Perm ε         = ε
    Swp★⇒Perm (x ◅ xs) = Swp⇒Perm x ⁏ Swp★⇒Perm xs

    swp-inners : ∀ {n} → SwpOp (2 + n)
    swp-inners = second-swpop swp ⁏ swp-seconds ⁏ second-swpop swp

    on-extremes : ∀ {n} → SwpOp (1 + n) → SwpOp (2 + n)
    on-extremes f = swp-seconds ⁏ first f ⁏ swp-seconds

    on-firsts : ∀ {n} → SwpOp (1 + n) → SwpOp (2 + n)
    on-firsts f = swp-inners ⁏ first f ⁏ swp-inners

    0↔_ : ∀ {m n} → Bits m → SwpOp (m + n)
    0↔ [] = ε
    0↔ (false{-0-} ∷ p) = first (0↔ p)
    0↔ (true{-1-}  ∷ []) = swp
    0↔ (true{-1-}  ∷ true {-1-} ∷ p) = on-extremes (0↔ (1b ∷ p))
    0↔ (true{-1-}  ∷ false{-0-} ∷ p) = on-firsts   (0↔ (1b ∷ p))

    commSwpOp : ∀ m n → SwpOp (m + n) → SwpOp (n + m)
    commSwpOp m n x rewrite ℕ°.+-comm m n = x

    [_↔_] : ∀ {m n} (p q : Bits m) → SwpOp (m + n)
    [ p ↔ q ] = 0↔ p ⁏ 0↔ q ⁏ 0↔ p

    [_↔′_] : ∀ {n} (p q : Bits n) → SwpOp n
    [ p ↔′ q ] = commSwpOp _ 0 [ p ↔ q ]

    _$swp_ : ∀ {n a} {A : Set a} → SwpOp n → Tree A n → Tree A n
    ε           $swp t = t
    (f ⁏ g)     $swp t = g $swp (f $swp t)
    (first f)   $swp (fork t₀ t₁) = fork (f $swp t₀) t₁
    swp         $swp (fork t₀ t₁) = fork t₁ t₀
    swp-seconds $swp (fork (fork t₀ t₁) (fork t₂ t₃)) = fork (fork t₀ t₃) (fork t₂ t₁)

    swpRel : ∀ {n a} {A : Set a} (f : SwpOp n) (t : Tree A n) → Perm t (f $swp t)
    swpRel ε           _          = ε
    swpRel (f ⁏ g)     _          = swpRel f _ ⁏ swpRel g _
    swpRel (first f)   (fork _ _) = first (swpRel f _)
    swpRel swp         (fork _ _) = swp
    swpRel swp-seconds
     (fork (fork _ _) (fork _ _)) = swp-seconds

    [0↔_]-Rel : ∀ {m n a} {A : Set a} (p : Bits m) (t : Tree A (m + n)) → Perm t ((0↔ p) $swp t)
    [0↔ p ]-Rel = swpRel (0↔ p)

    swpOp' : ∀ {n a} {A : Set a} {t u : Tree A n} → Perm0↔ t u → SwpOp n
    swpOp' ε = ε
    swpOp' (first f) = first (swpOp' f)
    swpOp' swp = swp
    swpOp' (firsts f) = on-firsts (swpOp' f)
    swpOp' (extremes f) = on-extremes (swpOp' f)

    swpOp : ∀ {n a} {A : Set a} {t u : Tree A n} → Perm t u → SwpOp n
    swpOp ε = ε
    swpOp (f ⁏ g) = swpOp f ⁏  swpOp g
    swpOp (first f) = first (swpOp f)
    swpOp swp = swp
    swpOp swp-seconds = swp-seconds

    swpOp-sym : ∀ {n} → SwpOp n → SwpOp n
    swpOp-sym ε = ε
    swpOp-sym (f ⁏ g) = swpOp-sym g ⁏ swpOp-sym f
    swpOp-sym (first f) = first (swpOp-sym f)
    swpOp-sym swp = swp
    swpOp-sym swp-seconds = swp-seconds

    swpOp-sym-involutive : ∀ {n} (f : SwpOp n) → swpOp-sym (swpOp-sym f) ≡ f
    swpOp-sym-involutive ε = ≡.refl
    swpOp-sym-involutive (f ⁏ g) rewrite swpOp-sym-involutive f | swpOp-sym-involutive g = ≡.refl
    swpOp-sym-involutive (first f) rewrite swpOp-sym-involutive f = ≡.refl
    swpOp-sym-involutive swp = ≡.refl
    swpOp-sym-involutive swp-seconds = ≡.refl

    swpOp-sym-sound : ∀ {n a} {A : Set a} (f : SwpOp n) (t : Tree A n) → swpOp-sym f $swp (f $swp t) ≡ t
    swpOp-sym-sound ε t = ≡.refl
    swpOp-sym-sound (f ⁏ g) t rewrite swpOp-sym-sound g (f $swp t) | swpOp-sym-sound f t = ≡.refl
    swpOp-sym-sound (first f) (fork t _) rewrite swpOp-sym-sound f t = ≡.refl
    swpOp-sym-sound swp (fork _ _) = ≡.refl
    swpOp-sym-sound swp-seconds (fork (fork _ _) (fork _ _)) = ≡.refl

    module ¬swp-comm where
      data X : Set where
        A B C D E F G H : X
      n : ℕ
      n = 3
      t : Tree X n
      t = fork (fork (fork (leaf A) (leaf B))(fork (leaf C) (leaf D))) (fork (fork (leaf E) (leaf F))(fork (leaf G) (leaf H)))
      f : SwpOp n
      f = swp
      g : SwpOp n
      g = first swp
      pf : f $swp (g $swp t) ≢ g $swp (f $swp t)
      pf ()

    swp-leaf : ∀ {a} {A : Set a} (f : SwpOp 0) (x : A) → f $swp (leaf x) ≡ leaf x
    swp-leaf ε x = ≡.refl
    swp-leaf (f ⁏ g) x rewrite swp-leaf f x | swp-leaf g x = ≡.refl

    swpOp-sound : ∀ {n a} {A : Set a} {t u : Tree A n} (perm : Perm t u) → (swpOp perm $swp t ≡ u)
    swpOp-sound ε = ≡.refl
    swpOp-sound (f ⁏ f₁) rewrite swpOp-sound f | swpOp-sound f₁ = ≡.refl
    swpOp-sound (first f) rewrite swpOp-sound f = ≡.refl
    swpOp-sound swp = ≡.refl
    swpOp-sound swp-seconds = ≡.refl

open import Relation.Nullary using (Dec ; yes ; no)
open import Relation.Nullary.Negation


module new-approach where

  open Rot
  open SwpOp
  open import Data.Empty

  import Function.Inverse as FI
  open FI using (_↔_; module Inverse; _InverseOf_)
  open import Function.Related
  import Function.Equality
  import Relation.Binary.PropositionalEquality as P

  data _∈_ {a}{A : Set a}(x : A) : {n : ℕ} → Tree A n → Set a where
    here  : x ∈ leaf x
    left  : {n : ℕ}{t₁ t₂ : Tree A n} → x ∈ t₁ → x ∈ fork t₁ t₂
    right : {n : ℕ}{t₁ t₂ : Tree A n} → x ∈ t₂ → x ∈ fork t₁ t₂

  toBits : ∀ {a}{A : Set a}{x : A}{n : ℕ}{t : Tree A n} → x ∈ t → Bits n
  toBits here = []
  toBits (left key) = 0b ∷ toBits key
  toBits (right key) = 1b ∷ toBits key

  ∈-lookup : ∀ {a}{A : Set a}{x : A}{n : ℕ}{t : Tree A n}(path : x ∈ t) → lookup (toBits path) t ≡ x
  ∈-lookup here = ≡.refl
  ∈-lookup (left path) = ∈-lookup path
  ∈-lookup (right path) = ∈-lookup path

  lookup-∈ : ∀ {a}{A : Set a}{n : ℕ}(key : Bits n)(t : Tree A n) → lookup key t ∈ t
  lookup-∈ [] (leaf x) = here
  lookup-∈ (true ∷ key) (fork tree tree₁) = right (lookup-∈ key tree₁)
  lookup-∈ (false ∷ key) (fork tree tree₁) = left (lookup-∈ key tree)

  _≈_ : ∀ {a}{A : Set a}{n : ℕ} → Tree A n → Tree A n → Set _
  t₁ ≈ t₂ = ∀ x → (x ∈ t₁) ↔ (x ∈ t₂)

  ≈-refl : {a : _}{A : Set a}{n : ℕ}{t : Tree A n} → t ≈ t
  ≈-refl _ = FI.id

  ≈-trans : {a : _}{A : Set a}{n : ℕ}{t u v : Tree A n} → t ≈ u → u ≈ v → t ≈ v
  ≈-trans f g x = g x FI.∘ f x

  move : ∀ {a}{A : Set a}{n : ℕ}{t s : Tree A n}{x : A} → t ≈ s → x ∈ t → x ∈ s
  move t≈s x∈t = Inverse.to (t≈s _) Function.Equality.⟨$⟩ x∈t

  swap₀ : ∀ {a}{A : Set a}{n : ℕ}{t₁ t₂ : Tree A n} → fork t₁ t₂ ≈ fork t₂ t₁
  swap₀ _ = record
    { to         = ≡.→-to-⟶ fun
    ; from       = ≡.→-to-⟶ fun
    ; inverse-of = record { left-inverse-of  = inv
                          ; right-inverse-of = inv }
    } where
       fun : ∀ {a}{A : Set a}{x : A}{n : ℕ}{t₁ t₂ : Tree A n} → x ∈ fork t₁ t₂ → x ∈ fork t₂ t₁
       fun (left path)  = right path
       fun (right path) = left path

       inv : ∀ {a}{A : Set a}{x : A}{n : ℕ}{t₁ t₂ : Tree A n}(p : x ∈ fork t₁ t₂) → fun (fun p) ≡ p
       inv (left p)  = ≡.refl
       inv (right p) = ≡.refl

  swap₂ : ∀ {a}{A : Set a}{n : ℕ}{tA tB tC tD : Tree A n}
          → fork (fork tA tB) (fork tC tD) ≈ fork (fork tA tD) (fork tC tB)
  swap₂ _ = record
    { to         = ≡.→-to-⟶ fun
    ; from       = ≡.→-to-⟶ fun
    ; inverse-of = record { left-inverse-of  = inv
                          ; right-inverse-of = inv }
    } where
       fun : ∀ {a}{A : Set a}{x n}{tA tB tC tD : Tree A n}
             → x ∈ fork (fork tA tB) (fork tC tD) → x ∈ fork (fork tA tD) (fork tC tB)
       fun (left (left path))  = left (left path)
       fun (left (right path)) = right (right path)
       fun (right (left path)) = right (left path)
       fun (right (right path)) = left (right path)

       inv : ∀ {a}{A : Set a}{x n}{tA tB tC tD : Tree A n}
             → (p : x ∈ fork (fork tA tB) (fork tC tD)) → fun (fun p) ≡ p
       inv (left (left p)) = ≡.refl
       inv (left (right p)) = ≡.refl
       inv (right (left p)) = ≡.refl
       inv (right (right p)) = ≡.refl

  _⟨fork⟩_ : ∀ {a}{A : Set a}{n : ℕ}{t₁ t₂ s₁ s₂ : Tree A n} → t₁ ≈ s₁ → t₂ ≈ s₂ → fork t₁ t₂ ≈ fork s₁ s₂
  (t1≈s1 ⟨fork⟩ t2≈s2) y = record
    { to         = to
    ; from       = from
    ; inverse-of = record { left-inverse-of  = frk-linv
                          ; right-inverse-of = frk-rinv  }
    } where

        frk : ∀ {a}{A : Set a}{n : ℕ}{t₁ t₂ s₁ s₂ : Tree A n}{x : A} → t₁ ≈ s₁ → t₂ ≈ s₂ → x ∈ fork t₁ t₂ → x ∈ fork s₁ s₂
        frk t1≈s1 t2≈s2 (left x∈t1) = left (move t1≈s1 x∈t1)
        frk t1≈s1 t2≈s2 (right x∈t2) = right (move t2≈s2 x∈t2)

        to = ≡.→-to-⟶ (frk t1≈s1 t2≈s2)
        from = ≡.→-to-⟶ (frk (λ x → FI.sym (t1≈s1 x)) (λ x → FI.sym (t2≈s2 x)))


        open Function.Equality using (_⟨$⟩_)
        open import Function.LeftInverse

        frk-linv : from LeftInverseOf to
        frk-linv (left x) = ≡.cong left (_InverseOf_.left-inverse-of (Inverse.inverse-of (t1≈s1 y)) x)
        frk-linv (right x) = ≡.cong right (_InverseOf_.left-inverse-of (Inverse.inverse-of (t2≈s2 y)) x)

        frk-rinv : from RightInverseOf to -- ∀ x → to ⟨$⟩ (from ⟨$⟩ x) ≡ x
        frk-rinv (left x) = ≡.cong left (_InverseOf_.right-inverse-of (Inverse.inverse-of (t1≈s1 y)) x)
        frk-rinv (right x) = ≡.cong right (_InverseOf_.right-inverse-of (Inverse.inverse-of (t2≈s2 y)) x)

  ≈-first : ∀ {a}{A : Set a}{n : ℕ}{t u v : Tree A n} → t ≈ u → fork t v ≈ fork u v
  ≈-first f = f ⟨fork⟩ ≈-refl

  ≈-second : ∀ {a}{A : Set a}{n : ℕ}{t u v : Tree A n} → t ≈ u → fork v t ≈ fork v u
  ≈-second f = ≈-refl ⟨fork⟩ f

  swap-inner : ∀ {a}{A : Set a}{n : ℕ}{tA tB tC tD : Tree A n}
          → fork (fork tA tB) (fork tC tD) ≈ fork (fork tA tC) (fork tB tD)
  swap-inner = ≈-trans (≈-second swap₀) (≈-trans swap₂ (≈-second swap₀))

  Rot⟶≈ : ∀ {a}{A : Set a}{n : ℕ}{t₁ t₂ : Tree A n} → Rot t₁ t₂ → t₁ ≈ t₂
  Rot⟶≈ (leaf x)        = ≈-refl
  Rot⟶≈ (fork rot rot₁) = Rot⟶≈ rot ⟨fork⟩ Rot⟶≈ rot₁
  Rot⟶≈ (krof {_} {l} {l'} {r} {r'} rot rot₁) = λ y →
        y ∈ fork l r ↔⟨ (Rot⟶≈ rot ⟨fork⟩ Rot⟶≈ rot₁) y ⟩
        y ∈ fork r' l' ↔⟨ swap₀ y ⟩
        y ∈ fork l' r' ∎
    where open EquationalReasoning

  Perm⟶≈ : ∀ {a}{A : Set a}{n : ℕ}{t₁ t₂ : Tree A n} → Perm t₁ t₂ → t₁ ≈ t₂
  Perm⟶≈ ε = ≈-refl
  Perm⟶≈ (f ⁏ g) = ≈-trans (Perm⟶≈ f) (Perm⟶≈ g)
  Perm⟶≈ (first f) = ≈-first (Perm⟶≈ f)
  Perm⟶≈ swp = swap₀
  Perm⟶≈ swp-seconds = swap₂

  Perm0↔⟶≈ : ∀ {a}{A : Set a}{n : ℕ}{t₁ t₂ : Tree A n} → Perm0↔ t₁ t₂ → t₁ ≈ t₂
  Perm0↔⟶≈ ε = ≈-refl
  Perm0↔⟶≈ swp = swap₀
  Perm0↔⟶≈ (first t) = ≈-first (Perm0↔⟶≈ t)
  Perm0↔⟶≈ (firsts t) = ≈-trans swap-inner (≈-trans (≈-first (Perm0↔⟶≈ t)) swap-inner)
  Perm0↔⟶≈ (extremes t) = ≈-trans swap₂ (≈-trans (≈-first (Perm0↔⟶≈ t)) swap₂)

  put : {a : _}{A : Set a}{n : ℕ} → Bits n → A → Tree A n → Tree A n
  put [] val tree = leaf val
  put (x ∷ key) val (fork tree tree₁) = if x then fork tree (put key val tree₁)
                                             else fork (put key val tree) tree₁

  -- move-me
  _∷≢_ : {n : ℕ}{xs ys : Bits n}(x : Bit) → x ∷ xs ≢ x ∷ ys → xs ≢ ys
  _∷≢_ x = contraposition $ ≡.cong $ _∷_ x

  ∈-put : {a : _}{A : Set a}{n : ℕ}(p : Bits n){x : A}(t : Tree A n) → x ∈ put p x t
  ∈-put [] t = here
  ∈-put (true ∷ p) (fork t t₁) = right (∈-put p t₁)
  ∈-put (false ∷ p) (fork t t₁) = left (∈-put p t)

  ∈-put-≢  : {a : _}{A : Set a}{n : ℕ}(p : Bits n){x y : A}{t : Tree A n}(path : x ∈ t)
          → p ≢ toBits path → x ∈ put p y t
  ∈-put-≢ [] here neg = ⊥-elim (neg ≡.refl)
  ∈-put-≢ (true ∷ p) (left path) neg   = left path
  ∈-put-≢ (false ∷ p) (left path) neg  = left (∈-put-≢ p path (false ∷≢ neg))
  ∈-put-≢ (true ∷ p) (right path) neg  = right (∈-put-≢ p path (true ∷≢ neg))
  ∈-put-≢ (false ∷ p) (right path) neg = right path

  {-
  swap : {a : _}{A : Set a}{n : ℕ} → (p₁ p₂ : Bits n) → Tree A n → Tree A n
  swap p₁ p₂ t = put p₁ a₂ (put p₂ a₁ t)
    where
      a₁ = lookup p₁ t
      a₂ = lookup p₂ t

  swap-perm₁ : {a : _}{A : Set a}{n : ℕ}{t : Tree A n}{x : A}(p : x ∈ t) → t ≈ swap (toBits p) (toBits p) t
  swap-perm₁ here         = ≈-refl
  swap-perm₁ (left path)  = ≈-first (swap-perm₁ path)
  swap-perm₁ (right path) = ≈-second (swap-perm₁ path)

  swap-comm : {a : _}{A : Set a}{n : ℕ} (p₁ p₂ : Bits n)(t : Tree A n) → swap p₂ p₁ t ≡ swap p₁ p₂ t
  swap-comm [] [] (leaf x) = refl
  swap-comm (true ∷ p₁) (true ∷ p₂) (fork t t₁) = ≡.cong (fork t) (swap-comm p₁ p₂ t₁)
  swap-comm (true ∷ p₁) (false ∷ p₂) (fork t t₁) = refl
  swap-comm (false ∷ p₁) (true ∷ p₂) (fork t t₁) = refl
  swap-comm (false ∷ p₁) (false ∷ p₂) (fork t t₁) = ≡.cong (flip fork t₁) (swap-comm p₁ p₂ t)

  swap-perm₂ : {a : _}{A : Set a}{n : ℕ}{t : Tree A n}{x : A}(p' : Bits n)(p : x ∈ t)
             → x ∈ swap (toBits p) p' t
  swap-perm₂ _ here = here
  swap-perm₂ (true ∷ p) (left path) rewrite ∈-lookup path = right (∈-put p _)
  swap-perm₂ (false ∷ p) (left path) = left (swap-perm₂ p path)
  swap-perm₂ (true ∷ p) (right path) = right (swap-perm₂ p path)
  swap-perm₂ (false ∷ p) (right path) rewrite ∈-lookup path = left (∈-put p _)

  swap-perm₃ : {a : _}{A : Set a}{n : ℕ}{t : Tree A n}{x : A}(p₁ p₂ : Bits n)(p : x ∈ t)
              → p₁ ≢ toBits p → p₂ ≢ toBits p → x ∈ swap p₁ p₂ t
  swap-perm₃ [] [] here neg₁ neg₂ = here
  swap-perm₃ (true ∷ p₁) (true ∷ p₂) (left path) neg₁ neg₂   = left path
  swap-perm₃ (true ∷ p₁) (false ∷ p₂) (left path) neg₁ neg₂  = left (∈-put-≢ _ path (false ∷≢ neg₂))
  swap-perm₃ (false ∷ p₁) (true ∷ p₂) (left path) neg₁ neg₂  = left (∈-put-≢ _ path (false ∷≢ neg₁))
  swap-perm₃ (false ∷ p₁) (false ∷ p₂) (left path) neg₁ neg₂ = left
             (swap-perm₃ p₁ p₂ path (false ∷≢ neg₁) (false ∷≢ neg₂))
  swap-perm₃ (true ∷ p₁) (true ∷ p₂) (right path) neg₁ neg₂   = right
             (swap-perm₃ p₁ p₂ path (true ∷≢ neg₁) (true ∷≢ neg₂))
  swap-perm₃ (true ∷ p₁) (false ∷ p₂) (right path) neg₁ neg₂  = right (∈-put-≢ _ path (true ∷≢ neg₁))
  swap-perm₃ (false ∷ p₁) (true ∷ p₂) (right path) neg₁ neg₂  = right (∈-put-≢ _ path (true ∷≢ neg₂))
  swap-perm₃ (false ∷ p₁) (false ∷ p₂) (right path) neg₁ neg₂ = right path
  -}

  ∈-swp : ∀ {n a} {A : Set a} (f : SwpOp n) {x : A} {t : Tree A n} → x ∈ t → x ∈ (f $swp t)
  ∈-swp ε pf = pf
  ∈-swp (f ⁏ g) pf = ∈-swp g (∈-swp f pf)
  ∈-swp (first f) {t = fork _ _} (left pf) = left (∈-swp f pf)
  ∈-swp (first f) {t = fork _ _} (right pf) = right pf
  ∈-swp swp {t = fork t u} (left pf) = right pf
  ∈-swp swp {t = fork t u} (right pf) = left pf
  ∈-swp swp-seconds {t = fork (fork _ _) (fork _ _)} (left (left pf)) = left (left pf)
  ∈-swp swp-seconds {t = fork (fork _ _) (fork _ _)} (left (right pf)) = right (right pf)
  ∈-swp swp-seconds {t = fork (fork _ _) (fork _ _)} (right (left pf)) = right (left pf)
  ∈-swp swp-seconds {t = fork (fork _ _) (fork _ _)} (right (right pf)) = left (right pf)

  ∈-fromFun : ∀ {m n x} (f : Bits m → Bits n) (p : x ∈ fromFun f) → f (toBits p) ≡ x
  ∈-fromFun f here      = ≡.refl
  ∈-fromFun f (left p)  = ∈-fromFun (f ∘ 0∷_) p
  ∈-fromFun f (right p) = ∈-fromFun (f ∘ 1∷_) p

  ∈-rev-app : ∀ {m} n {x : Bits (rev-+ m n)} (q : Bits m) (p : x ∈ fromFun (rev-app q)) → rev-app q (toBits p) ≡ x
  ∈-rev-app _ = ∈-fromFun ∘ rev-app

module fold-Properties {a} {A : Set a} (_·_ : Op₂ A) (op-comm : Commutative _≡_ _·_) (op-assoc : Associative _≡_ _·_) where
  open Rot

  ⟪_⟫ : ∀ {n} → Tree A n → A
  ⟪_⟫ = fold _·_

  _=[fold]⇒′_ : ∀ {ℓ₁ ℓ₂} → (∀ {m n} → REL (Tree A m) (Tree A n) ℓ₁) → Rel A ℓ₂ → Set _
  -- _∼₀_ =[fold]⇒ _∼₁_ = ∀ {m n} → _∼₀_ {m} {n} =[ fold {n} _·_ ]⇒ _∼₁_
  _∼₀_ =[fold]⇒′ _∼₁_ = ∀ {m n} {t : Tree A m} {u : Tree A n} → t ∼₀ u → ⟪ t ⟫ ∼₁ ⟪ u ⟫

  _=[fold]⇒_ : ∀ {ℓ₁ ℓ₂} → (∀ {n} → Rel (Tree A n) ℓ₁) → Rel A ℓ₂ → Set _
  _∼₀_ =[fold]⇒ _∼₁_ = ∀ {n} → _∼₀_ =[ fold {n} _·_ ]⇒ _∼₁_

  fold-rot : Rot =[fold]⇒ _≡_
  fold-rot (leaf x) = ≡.refl
  fold-rot (fork rot rot₁) = ≡.cong₂ _·_ (fold-rot rot) (fold-rot rot₁)
  fold-rot (krof rot rot₁) rewrite fold-rot rot | fold-rot rot₁ = op-comm _ _

  -- t ∼ u → fork v t ∼ fork u w

  lem : ∀ x y z t → (x · y) · (z · t) ≡ (t · y) · (z · x)
  lem x y z t = (x · y) · (z · t)
              ≡⟨ op-assoc x y _ ⟩
                x · (y · (z · t))
              ≡⟨ op-comm x _ ⟩
                (y · (z · t)) · x
              ≡⟨ op-assoc y (z · t) _ ⟩
                y · ((z · t) · x)
              ≡⟨ ≡.cong (λ u → y · (u · x)) (op-comm z t) ⟩
                y · ((t · z) · x)
              ≡⟨ ≡.cong (_·_ y) (op-assoc t z x) ⟩
                y · (t · (z · x))
              ≡⟨ ≡.sym (op-assoc y t _) ⟩
                (y · t) · (z · x)
              ≡⟨ ≡.cong (λ u → u · (z · x)) (op-comm y t) ⟩
                (t · y) · (z · x)
              ∎
    where open ≡-Reasoning

  fold-swp : Swp =[fold]⇒ _≡_
  fold-swp (left pf) rewrite fold-swp pf = ≡.refl
  fold-swp (right pf) rewrite fold-swp pf = ≡.refl
  fold-swp swp₁ = op-comm _ _
  fold-swp (swp₂ {_} {t₀₀} {t₀₁} {t₁₀} {t₁₁}) = lem ⟪ t₀₀ ⟫ ⟪ t₀₁ ⟫ ⟪ t₁₀ ⟫ ⟪ t₁₁ ⟫

  fold-swp★ : Swp★ =[fold]⇒ _≡_
  fold-swp★ ε = ≡.refl
  fold-swp★ (x ◅ xs) rewrite fold-swp x | fold-swp★ xs = ≡.refl

module FoldProp {a ℓ} {A : Set a} (_Ⓧ_ : Set ℓ → Set ℓ → Set ℓ) where
    Fold : ∀ {n} → (Bits n → A → Set ℓ) → Tree A n → Set ℓ
    Fold f (leaf x)     = f [] x
    Fold f (fork t₀ t₁) = Fold (f ∘ 0∷_) t₀ Ⓧ Fold (f ∘ 1∷_) t₁

All : ∀ {n a} {A : Set a} → (Bits n → A → Set) → Tree A n → Set
All = FoldProp.Fold _×_

Any : ∀ {n a} {A : Set a} → (Bits n → A → Set) → Tree A n → Set
Any = FoldProp.Fold _⊎_

module AllBits where
  _IsRevPrefixOf_ : ∀ {m n} → Bits m → Bits (rev-+ m n) → Set
  _IsRevPrefixOf_ {m} {n} p xs = ∃ λ (ys : Bits n) → rev-app p ys ≡ xs

  RevPrefix : ∀ {m n o} (p : Bits m) → Tree (Bits (rev-+ m n)) o → Set
  RevPrefix p = All (λ _ → _IsRevPrefixOf_ p)

  RevPrefix-[]-⊤ : ∀ {m n} (t : Tree (Bits m) n) → RevPrefix [] t
  RevPrefix-[]-⊤ (leaf x) = x , ≡.refl
  RevPrefix-[]-⊤ (fork t u) = RevPrefix-[]-⊤ t , RevPrefix-[]-⊤ u

  All-fromFun : ∀ {m} n (p : Bits m) → All (_≡_ ∘ rev-app p) (fromFun {n} (rev-app p))
  All-fromFun zero    p = ≡.refl
  All-fromFun (suc n) p = All-fromFun n (0∷ p) , All-fromFun n (1∷ p)

  All-id : ∀ n → All {n} _≡_ (fromFun id)
  All-id n = All-fromFun n []


first : ∀ {n a} {A : Set a} → Tree A n → A
first (leaf x)   = x
first (fork t _) = first t

last : ∀ {n a} {A : Set a} → Tree A n → A
last (leaf x)   = x
last (fork _ t) = last t

module SortedDataIx {a ℓ} {A : Set a} (_≤ᴬ_ : A → A → Set ℓ) (isPreorder : IsPreorder _≡_ _≤ᴬ_) where
    open new-approach
    data Sorted : ∀ {n} → Tree A n → A → A → Set (a L.⊔ ℓ) where
      leaf : {x : A} → Sorted (leaf x) x x
      fork : ∀ {n} {t u : Tree A n} {low_t high_t lowᵤ highᵤ} →
             Sorted t low_t high_t →
             Sorted u lowᵤ highᵤ →
             (h≤l : high_t ≤ᴬ lowᵤ) →
             Sorted (fork t u) low_t highᵤ

    private
        module ≤ᴬ = IsPreorder isPreorder

    ≤ᴬ-bounds : ∀ {n} {t : Tree A n} {l h} → Sorted t l h → l ≤ᴬ h
    ≤ᴬ-bounds leaf            = ≤ᴬ.refl
    ≤ᴬ-bounds (fork s₀ s₁ pf) = ≤ᴬ.trans (≤ᴬ-bounds s₀) (≤ᴬ.trans pf (≤ᴬ-bounds s₁))

    Sorted→lb : ∀ {n} {t : Tree A n} {l h} → Sorted t l h → ∀ {x} → x ∈ t → l ≤ᴬ x
    Sorted→lb leaf            here      = ≤ᴬ.refl
    Sorted→lb (fork s _ _)    (left  p) = Sorted→lb s p
    Sorted→lb (fork s₀ s₁ pf) (right p) = ≤ᴬ.trans (≤ᴬ.trans (≤ᴬ-bounds s₀) pf) (Sorted→lb s₁ p)

    Sorted→ub : ∀ {n} {t : Tree A n} {l h} → Sorted t l h → ∀ {x} → x ∈ t → x ≤ᴬ h
    Sorted→ub leaf            here      = ≤ᴬ.refl
    Sorted→ub (fork _ s _)    (right p) = Sorted→ub s p
    Sorted→ub (fork s₀ s₁ pf) (left  p) = ≤ᴬ.trans (≤ᴬ.trans (Sorted→ub s₀ p) pf) (≤ᴬ-bounds s₁)

    Bounded : ∀ {n} → Tree A n → A → A → Set (a L.⊔ ℓ)
    Bounded t l h = ∀ {x} → x ∈ t → (l ≤ᴬ x) × (x ≤ᴬ h)

    Sorted→Bounded : ∀ {n} {t : Tree A n} {l h} → Sorted t l h → Bounded t l h
    Sorted→Bounded s x = Sorted→lb s x , Sorted→ub s x

    first-lb : ∀ {n} {t : Tree A n} {l h} → Sorted t l h → first t ≡ l
    first-lb leaf          = ≡.refl
    first-lb (fork st _ _) = first-lb st

    last-ub : ∀ {n} {t : Tree A n} {l h} → Sorted t l h → last t ≡ h
    last-ub leaf          = ≡.refl
    last-ub (fork _ st _) = last-ub st

    uniq-lb : ∀ {n} {t : Tree A n} {l₀ h₀ l₁ h₁}
                  → Sorted t l₀ h₀ → Sorted t l₁ h₁ → l₀ ≡ l₁
    uniq-lb leaf leaf = ≡.refl
    uniq-lb (fork p p₁ h≤l) (fork q q₁ h≤l₁) = uniq-lb p q

    uniq-ub : ∀ {n} {t : Tree A n} {l₀ h₀ l₁ h₁}
                  → Sorted t l₀ h₀ → Sorted t l₁ h₁ → h₀ ≡ h₁
    uniq-ub leaf leaf = ≡.refl
    uniq-ub (fork p p₁ h≤l) (fork q q₁ h≤l₁) = uniq-ub p₁ q₁

    Sorted-trans : ∀ {n} {t u v : Tree A n} {lt hu lu hv}
                   → Sorted (fork t u) lt hu → Sorted (fork u v) lu hv → Sorted (fork t v) lt hv
    Sorted-trans {lt = lt} {hu} {lu} {hv} (fork tu tu₁ h≤l) (fork uv uv₁ h≤l₁)
       rewrite uniq-lb uv tu₁
             | uniq-ub uv tu₁
         = fork tu uv₁ (≤ᴬ.trans h≤l (≤ᴬ.trans (≤ᴬ-bounds tu₁) h≤l₁))

module SortedData {a ℓ} {A : Set a} (_≤ᴬ_ : A → A → Set ℓ) (isPreorder : IsPreorder _≡_ _≤ᴬ_) where
    data Sorted : ∀ {n} → Tree A n → Set (a L.⊔ ℓ) where
      leaf : {x : A} → Sorted (leaf x)
      fork : ∀ {n} {t u : Tree A n} →
             Sorted t →
             Sorted u →
             (h≤l : last t ≤ᴬ first u) →
             Sorted (fork t u)

    PreSorted : ∀ {n} → Tree A (1 + n) → Set _
    PreSorted t = Sorted (lft t) × Sorted (rght t)

    private
        module ≤ᴬ = IsPreorder isPreorder

    ≤ᴬ-bounds : ∀ {n} {t : Tree A n} → Sorted t → first t ≤ᴬ last t
    ≤ᴬ-bounds leaf            = ≤ᴬ.refl
    ≤ᴬ-bounds (fork s₀ s₁ pf) = ≤ᴬ.trans (≤ᴬ-bounds s₀) (≤ᴬ.trans pf (≤ᴬ-bounds s₁))

    Sorted→lb : ∀ {n} {t : Tree A n} → Sorted t → ∀ (p : Bits n) → first t ≤ᴬ lookup p t
    Sorted→lb leaf             []          = ≤ᴬ.refl
    Sorted→lb (fork st su h≤l) (true  ∷ p) = ≤ᴬ.trans (≤ᴬ.trans (≤ᴬ-bounds st) h≤l) (Sorted→lb su p)
    Sorted→lb (fork st _  _)   (false ∷ p) = Sorted→lb st p

    Sorted→ub : ∀ {n} {t : Tree A n} → Sorted t → ∀ (p : Bits n) → lookup p t ≤ᴬ last t
    Sorted→ub leaf             []          = ≤ᴬ.refl
    Sorted→ub (fork _  su _)   (true  ∷ p) = Sorted→ub su p
    Sorted→ub (fork st su h≤l) (false ∷ p) = ≤ᴬ.trans (≤ᴬ.trans (Sorted→ub st p) h≤l) (≤ᴬ-bounds su)

    Bounded : ∀ {n} → Tree A n → A → A → Set ℓ
    Bounded {n} t l h = ∀ (p : Bits n) → (l ≤ᴬ lookup p t) × (lookup p t ≤ᴬ h)

    Sorted→Bounded : ∀ {n} {t : Tree A n} → Sorted t → Bounded t (first t) (last t)
    Sorted→Bounded s x = Sorted→lb s x , Sorted→ub s x

module SortedMembershipProofs {a ℓ} {A : Set a} (_≤ᴬ_ : A → A → Set ℓ) (isPreorder : IsPreorder _≡_ _≤ᴬ_) where
    open new-approach

    _≤ᴾ_ : ∀ {n x y} {t : Tree A n} → x ∈ t → y ∈ t → Set
    p ≤ᴾ q = toBits p ≤ᴮ toBits q

    Sorted : ∀ {n} → Tree A n → Set _
    Sorted t = ∀ {x} (p : x ∈ t) {y} (q : y ∈ t) → p ≤ᴾ q → x ≤ᴬ y

    private
        module ≤ᴬ = IsPreorder isPreorder

    module S = SortedDataIx _≤ᴬ_ isPreorder
    open S using (leaf; fork)
    Sorted→Sorted' : ∀ {n l h} {t : Tree A n} → S.Sorted t l h → Sorted t
    Sorted→Sorted' leaf             here     here       p≤q = ≤ᴬ.refl
    Sorted→Sorted' (fork s _ _)     (left p) (left q)   (there ._ p≤q) = Sorted→Sorted' s p q p≤q
    Sorted→Sorted' (fork s₀ s₁ l≤h) (left p) (right q)  p≤q = ≤ᴬ.trans (S.Sorted→ub s₀ p) (≤ᴬ.trans l≤h (S.Sorted→lb s₁ q))
    Sorted→Sorted' (fork _ _ _)     (right _) (left _)  ()
    Sorted→Sorted' (fork _ s _)     (right p) (right q) (there ._ p≤q) = Sorted→Sorted' s p q p≤q

module SortedMonotonicFunctions {a ℓ} {A : Set a} (_≤ᴬ_ : A → A → Set ℓ) (isPreorder : IsPreorder _≡_ _≤ᴬ_) where
    Monotone : ∀ {n} → (Bits n → A) → Set _
    Monotone {n} f = ∀ {p q : Bits n} → p ≤ᴮ q → f p ≤ᴬ f q

    Sorted : ∀ {n} → Tree A n → Set _
    Sorted = Monotone ∘ toFun

    private
        module ≤ᴬ = IsPreorder isPreorder

    open SortedData _≤ᴬ_ isPreorder renaming (Sorted to DataSorted)
    DataSorted→Sorted : ∀ {n} {t : Tree A n} → DataSorted t → Sorted t
    DataSorted→Sorted leaf             []                = ≤ᴬ.refl
    DataSorted→Sorted (fork _  su _)   (there true  p≤q) = DataSorted→Sorted su p≤q
    DataSorted→Sorted (fork st _  _)   (there false p≤q) = DataSorted→Sorted st p≤q
    DataSorted→Sorted (fork st su h≤l) (0-1 p q)         = ≤ᴬ.trans (≤ᴬ.trans (Sorted→ub st p) h≤l) (Sorted→lb su q)

module Sorting {a} {A : Set a} (_⊓ᴬ_ _⊔ᴬ_ : A → A → A) where

    sort-× : Endo (A × A)
    sort-× (x₀ , x₁) = (x₀ ⊓ᴬ x₁ , x₀ ⊔ᴬ x₁)

    sort₁ : Endo (Tree A 1)
    sort₁ = from-× ∘ sort-× ∘ to-×

    merge : ∀ {n} → Endo (Tree A (1 + n))
    merge {zero}  = sort₁
    merge {suc _} = map-inner merge ∘ map-outer merge merge ∘ interchange

    sort : ∀ {n} → Tree A n → Tree A n
    sort {zero}  = id
    sort {suc n} = merge ∘ map-outer sort sort

module EvalTree where
    open OperationSyntax renaming (map-inner to `map-inner; map-outer to `map-outer)
    evalTree : ∀ {n a} {A : Set a} → Bij n → Endo (Tree A n)
    evalTree `id          = id
    evalTree (op₀ `⁏ op₁) = evalTree op₁ ∘ evalTree op₀
    evalTree (`id   `∷ g) = map-outer (evalTree (g 0b)) (evalTree (g 1b))
    evalTree (`notᴮ `∷ g) = map-outer (evalTree (g 1b)) (evalTree (g 0b)) ∘ swap
    evalTree `0↔1         = interchange

    evalTree-eval : ∀ {n a} {A : Set a} (f : Bij n) (t : Tree A n) → toFun t ≗ toFun (evalTree f t) ∘ eval f
    evalTree-eval `id t xs = ≡.refl
    evalTree-eval `0↔1 (fork (fork a b) (fork c d)) (true ∷ true ∷ xs) = ≡.refl
    evalTree-eval `0↔1 (fork (fork a b) (fork c d)) (false ∷ true ∷ xs) = ≡.refl
    evalTree-eval `0↔1 (fork (fork a b) (fork c d)) (true ∷ false ∷ xs) = ≡.refl
    evalTree-eval `0↔1 (fork (fork a b) (fork c d)) (false ∷ false ∷ xs) = ≡.refl
    evalTree-eval (f `⁏ f₁) t xs = ≡.trans (evalTree-eval f t xs) (evalTree-eval f₁ (evalTree f t) (eval f xs))
    evalTree-eval (`id `∷ f) (fork t u) (true ∷ xs) = evalTree-eval (f 1b) u xs
    evalTree-eval (`id `∷ f) (fork t u) (false ∷ xs) = evalTree-eval (f 0b) t xs
    evalTree-eval (`notᴮ `∷ f) (fork t u) (true ∷ xs) = evalTree-eval (f 1b) u xs
    evalTree-eval (`notᴮ `∷ f) (fork t u) (false ∷ xs) = evalTree-eval (f 0b) t xs

    evalTree-eval′ : ∀ {n a} {A : Set a} (f : Bij n) (t : Tree A n) → toFun (evalTree f t) ≗ toFun t ∘ eval (f ⁻¹)
    evalTree-eval′ f t x = toFun (evalTree f t) x
                         ≡⟨ ≡.cong (toFun (evalTree f t)) (≡.sym (VecBijKit._⁻¹-inverse′ _ f x)) ⟩
                           toFun (evalTree f t) (eval f (eval (f ⁻¹) x))
                         ≡⟨ ≡.sym (evalTree-eval f t (eval (f ⁻¹) x)) ⟩
                           toFun t (eval (f ⁻¹) x)
                         ∎ where open ≡-Reasoning

module PermTreeProof where
    open EvalTree
    open OperationSyntax renaming (map-inner to `map-inner; map-outer to `map-outer)
    record Perm {A : Set} n (f : Endo (Tree A n)) : Set where
      constructor mk
      field
        perm  :  Tree A n → Bij n
        proof : (t : Tree A n) → t ≡ evalTree (perm t) (f t)

    id-proof : ∀ {A : Set}{n} → Perm {A} n id
    id-proof = mk (λ _ → `id) (λ t → ≡.refl)

    _∘-proof_ : ∀{A : Set}{n }{f g : Endo (Tree A n)} → Perm n f → Perm n g → Perm n (f ∘ g)
    _∘-proof_ {f = f}{g} (mk `f pf) (mk `g pg)
      = mk (λ t → `f (g t) `⁏ `g t)
           (λ t → ≡.trans (pg t) (≡.cong (evalTree (`g t)) (pf (g t))))

    swap-proof : ∀ {A : Set}{n} → Perm {A} (suc n) swap
    swap-proof = mk (λ _ → `not) ηfork

    map-outer-proof : ∀ {A : Set}{n}{f g : Endo (Tree A n)} → Perm n f → Perm n g → Perm {A} (suc n) (map-outer f g)
    map-outer-proof `f `g = mk (λ t → `map-outer (perm `f (lft t)) (perm `g (rght t)))
                               (λ { (fork t u) → ≡.cong₂ fork (proof `f t) (proof `g u) })
       where open Perm

    map-inner-proof : ∀ {A : Set}{n}{f : Endo (Tree A (1 + n))} → Perm (1 + n) f → Perm (2 + n) (map-inner f)
    map-inner-proof {A} {f = f} `f = mk map-inner-perm helper
       where open Perm
             map-inner-perm = `map-inner ∘ perm `f ∘ inner
             helper : ∀ t → t ≡ evalTree (map-inner-perm t) (map-inner f t)
             helper (fork (fork a b) (fork c d)) with f (fork b c) | ≡.sym (proof `f (fork b c))
             ... | fork B C | p rewrite p = ≡.refl

module Sorting-Perm-Properties {OT : Set} (_<=ᴬ_ : OT → OT → Bool)
    (isTotalOrder : IsTotalOrder _≡_ (λ x y → T (x <=ᴬ y)))
    where
    open IsTotalOrder isTotalOrder

    _⊓ᴬ_ : OT → OT → OT
    x ⊓ᴬ y = if x <=ᴬ y then x else y

    _⊔ᴬ_ : OT → OT → OT
    x ⊔ᴬ y = if x <=ᴬ y then y else x

    open Sorting _⊓ᴬ_ _⊔ᴬ_
    open EvalTree
    open OperationSyntax renaming (map-inner to `map-inner; map-outer to `map-outer)
    open PermTreeProof

    `sort₁ : Tree OT 1 → Bij 1
    `sort₁ = `xor ∘ uncurry _<=ᴬ_ ∘ swap-× ∘ to-×

    -- ∀ x  T (y <=ᴬ x) → fork (leaf x) (leaf y) ≡ fork (leaf (x ⊓ y)) (leaf (x ⊔ y))
    sort₁-proof : Perm {OT} 1 sort₁
    sort₁-proof = mk `sort₁ helper
      where helper : ∀ t → t ≡ evalTree (`sort₁ t) (sort₁ t)
            helper (fork (leaf x) (leaf y)) with y <=ᴬ x | x <=ᴬ y | antisym {x} {y} | total x y
            ... | true  | true  | p | _ rewrite p _ _ = ≡.refl
            ... | false | true  | _ | _ = ≡.refl
            ... | true  | false | _ | _ = ≡.refl
            ... | false | false | _ | inj₁ ()
            ... | false | false | _ | inj₂ ()

    merge-proof : ∀ {n} → Perm {OT} (suc n) merge
    merge-proof {zero}  = sort₁-proof
    merge-proof {suc n} = map-inner-proof merge-proof ∘-proof
                            (map-outer-proof merge-proof merge-proof ∘-proof
                             map-inner-proof swap-proof)

    sort-proof : ∀ {n} → Perm {OT} n sort
    sort-proof {zero}  = id-proof
    sort-proof {suc n} = merge-proof ∘-proof map-outer-proof sort-proof sort-proof

module MergeSwap {a} {A : Set a}
                 (_⊓ᴬ_ _⊔ᴬ_ : A → A → A)
                 (⊓-comm : Commutative _≡_ _⊓ᴬ_)
                 (⊔-comm : Commutative _≡_ _⊔ᴬ_) where
    open Sorting _⊓ᴬ_ _⊔ᴬ_
    merge-swap : ∀ {n} (t : Tree A (1 + n)) → merge t ≡ merge (swap t)
    merge-swap (fork (leaf x) (leaf y)) rewrite ⊔-comm x y | ⊓-comm y x = ≡.refl
    merge-swap (fork (fork t₀ t₁) (fork u₀ u₁))
      rewrite merge-swap (fork t₀ u₀)
            | merge-swap (fork t₁ u₁) = ≡.refl

module SortingDataIxProperties {ℓ a} {A : Set a} (_≤ᴬ_ : A → A → Set ℓ)
                               (_⊓ᴬ_ _⊔ᴬ_ : A → A → A)
                               (isPreorder : IsPreorder _≡_ _≤ᴬ_)
                               (⊔-spec : ∀ {x y} → x ≤ᴬ y → x ⊔ᴬ y ≡ y)
                               (⊓-spec : ∀ {x y} → x ≤ᴬ y → x ⊓ᴬ y ≡ x)
                               (⊓-comm : Commutative _≡_ _⊓ᴬ_)
                               (⊔-comm : Commutative _≡_ _⊔ᴬ_)
                               where
    open MergeSwap _⊓ᴬ_ _⊔ᴬ_ ⊓-comm ⊔-comm
    module ≤ᴬ = IsPreorder isPreorder
    open SortedDataIx _≤ᴬ_ isPreorder
    open Sorting _⊓ᴬ_ _⊔ᴬ_

    merge-pres : ∀ {n} {t : Tree A (1 + n)} {l h} → Sorted t l h → merge t ≡ t
    merge-pres (fork leaf leaf x) = ≡.cong₂ (fork on leaf) (⊓-spec x) (⊔-spec x)
    merge-pres {t = fork (fork t₀ t₁) (fork u₀ u₁)}
               (fork (fork {low_t = lt₀} {ht₀} {lt₁} {ht₁} st₀ st₁ ht₀≤lt₁)
                     (fork {low_t = lu₀} {hu₀} {lu₁} {hu₁} su₀ su₁ hu₀≤lu₁) ht₁≤lu₀)
       rewrite merge-pres (fork st₀ su₀ (≤ᴬ.trans ht₀≤lt₁ (≤ᴬ.trans (≤ᴬ-bounds st₁) ht₁≤lu₀)))
             | merge-pres (fork st₁ su₁ (≤ᴬ.trans ht₁≤lu₀ (≤ᴬ.trans (≤ᴬ-bounds su₀) hu₀≤lu₁)))
             | merge-swap (fork u₀ t₁)
             | merge-pres (fork st₁ su₀ ht₁≤lu₀) = ≡.refl

module SortingProperties {ℓ a} {A : Set a} (_≤ᴬ_ : A → A → Set ℓ)
                               (_⊓ᴬ_ _⊔ᴬ_ : A → A → A)
                               (isPreorder : IsPreorder _≡_ _≤ᴬ_)
                               (≤-⊔ : ∀ x y → x ≤ᴬ (y ⊔ᴬ x))
                               (⊓-≤ : ∀ x y → (x ⊓ᴬ y) ≤ᴬ y)
                               (≤-<_,_> : ∀ {x y z} → x ≤ᴬ y → x ≤ᴬ z → x ≤ᴬ (y ⊓ᴬ z))
                               (≤-[_,_] : ∀ {x y z} → x ≤ᴬ z → y ≤ᴬ z → (x ⊔ᴬ y) ≤ᴬ z)
                               (≤-⊓₀ : ∀ {x y z} → x ≤ᴬ (y ⊓ᴬ z) → x ≤ᴬ y)
                               (≤-⊓₁ : ∀ {x y z} → x ≤ᴬ (y ⊓ᴬ z) → x ≤ᴬ z)
                               (≤-⊔₀ : ∀ {x y z} → (x ⊔ᴬ y) ≤ᴬ z → x ≤ᴬ z)
                               (≤-⊔₁ : ∀ {x y z} → (x ⊔ᴬ y) ≤ᴬ z → y ≤ᴬ z)
                               where
    module ≤ᴬ = IsPreorder isPreorder
    open Sorting _⊓ᴬ_ _⊔ᴬ_
    module SD = SortedData _≤ᴬ_ isPreorder
    open SD using (fork; leaf; PreSorted)

    first-merge : ∀ {n} (t : Tree A (1 + n)) →
                first (merge t) ≡ first (lft t) ⊓ᴬ first (rght t)
    first-merge (fork (leaf x) (leaf y)) = ≡.refl
    first-merge (fork (fork t₀ t₁) (fork u₀ u₁))
      with merge (fork t₀ u₀) | first-merge (fork t₀ u₀)
         | merge (fork t₁ u₁)
    ... | fork v₀ w₀ | pf
        | fork v₁ w₁
      with merge (fork w₀ v₁)
    ... | fork a b
      = pf

    last-merge : ∀ {n} (t : Tree A (1 + n)) →
                last (merge t) ≡ last (lft t) ⊔ᴬ last (rght t)
    last-merge (fork (leaf x) (leaf y)) = ≡.refl
    last-merge (fork (fork t₀ t₁) (fork u₀ u₁))
      with merge (fork t₀ u₀)
         | merge (fork t₁ u₁) | last-merge (fork t₁ u₁)
    ... | fork v₀ w₀
        | fork v₁ w₁ | pf
      with merge (fork w₀ v₁)
    ... | fork a b
      = pf

    merge-spec′ : ∀ {n} {t u : Tree A n} →
                 SD.Sorted t → SD.Sorted u →
                 let tu' = merge (fork t u) in
                 SD.Sorted tu'
                 × last (lft tu') ≤ᴬ (last t ⊓ᴬ last u)
                 × (first t ⊔ᴬ first u) ≤ᴬ first (rght tu')
    merge-spec′ (leaf {x}) (leaf {y}) = fork leaf leaf (≤ᴬ.trans (⊓-≤ x y) (≤-⊔ y x)) , ≤ᴬ.refl , ≤ᴬ.refl
    merge-spec′ {t = fork t₀ t₁} {u = fork u₀ u₁}
               (fork st₀ st₁ ht₀≤lt₁)
               (fork su₀ su₁ lu₀≤hu₁)
      with merge (fork t₀ u₀) | merge-spec′ st₀ su₀ | last-merge (fork t₀ u₀)
         | merge (fork t₁ u₁) | merge-spec′ st₁ su₁ | first-merge (fork t₁ u₁)
    ... | fork v₀ w₀ | (fork sv₀ sw₀ p1 , lpf1 , rpf1) | lastw₀
        | fork v₁ w₁ | (fork sv₁ sw₁ p2 , lpf2 , rpf2) | firstv₁
      with merge (fork w₀ v₁) | merge-spec′ sw₀ sv₁ | first-merge (fork w₀ v₁) | last-merge (fork w₀ v₁)
    ... | fork a b | (fork sa sb p3 , lpf3 , rpf3) | firsta | lastb
      = fork (fork sv₀ sa pf1) (fork sb sw₁ pf2) p3 , lpf4 , rpf4
         where
             pf1 : last v₀ ≤ᴬ first a
             pf1 rewrite firsta | firstv₁ = ≤-< p1 , ≤-< ≤ᴬ.trans (≤-⊓₀ lpf1) ht₀≤lt₁ , ≤ᴬ.trans (≤-⊓₁ lpf1) lu₀≤hu₁ > >
             pf2 : last b ≤ᴬ first w₁
             pf2 rewrite lastb | lastw₀ = ≤-[ ≤-[ ≤ᴬ.trans ht₀≤lt₁ (≤-⊔₀ rpf2) , ≤ᴬ.trans lu₀≤hu₁ (≤-⊔₁ rpf2) ] , p2 ]
             lpf4 = ≤-< ≤ᴬ.trans (≤-⊓₁ lpf3) (≤-⊓₀ lpf2) , ≤ᴬ.trans (≤-⊓₁ lpf3) (≤-⊓₁ lpf2) >
             rpf4 = ≤-[ ≤ᴬ.trans (≤-⊔₀ rpf1) (≤-⊔₀ rpf3) , ≤ᴬ.trans (≤-⊔₁ rpf1) (≤-⊔₀ rpf3) ]

    merge-spec : ∀ {n} {t : Tree A (1 + n)} → PreSorted t → SD.Sorted (merge t)
    merge-spec {t = fork t u} (st , su) = proj₁ (merge-spec′ st su)

    sort-spec : ∀ {n} (t : Tree A n) → SD.Sorted (sort t)
    sort-spec (leaf _)   = leaf
    sort-spec (fork t u) = merge-spec (sort-spec t , sort-spec u)

module BitsSorting {m} where
    open ToNat {A = Bits m} toℕ (λ {x} {y} → toℕ-inj x y) public

    module S = Sorting _⊓_ _⊔_
    module SDP = SortingDataIxProperties _≤_ _⊓_ _⊔_ isPreorder (λ {x} {y} z → ⊔-spec {x} {y} z)
                   (λ {x} {y} → ⊓-spec {x} {y}) ⊓-comm ⊔-comm
    module SP = SortingProperties _≤_ _⊓_ _⊔_ isPreorder
                   ≤-⊔ ⊓-≤
                   (λ {x} {y} {z} → ≤-<_,_> {x} {y} {z})
                   (λ {x} {y} {z} → ≤-[_,_] {x} {y} {z})
                   (λ {x} {y} {z} → ≤-⊓₀ {x} {y} {z})
                   (λ {x} {y} {z} → ≤-⊓₁ {x} {y} {z})
                   (λ {x} {y} {z} → ≤-⊔₀ {x} {y} {z})
                   (λ {x} {y} {z} → ≤-⊔₁ {x} {y} {z})
    open SortedData _≤_ isPreorder public
    module SPP = Sorting-Perm-Properties _<=_ isTotalOrder
    open EvalTree public using (evalTree)

    merge : ∀ {n} → Tree (Bits m) (1 + n) → Tree (Bits m) (1 + n)
    merge = S.merge

    sort : ∀ {n} → Tree (Bits m) n → Tree (Bits m) n
    sort = S.sort

    merge-spec : ∀ {n} {t : Tree (Bits m) (1 + n)} → PreSorted t → Sorted (merge t)
    merge-spec = SP.merge-spec

    sort-spec : ∀ {n} (t : Tree (Bits m) n) → Sorted (sort t)
    sort-spec = SP.sort-spec

-- -}
-- -}
-- -}
-- -}
