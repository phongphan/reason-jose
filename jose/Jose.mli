(**
{1 JSON Web Algorithm}

{{: https://www.tools.ietf.org/rfc/rfc7518.html } Link to RFC }
*)
module Jwa : sig
  type alg =
    | RS256  (** HMAC using SHA-256 *)
    | HS256  (** RSASSA-PKCS1-v1_5 using SHA-256 *)
    | RSA_OAEP  (** RSA OAEP using default parameters *)
    | RSA1_5 (** RSA PKCS 1.5 *)
    | None
    | Unsupported of string

  (**
  {{: https://tools.ietf.org/html/rfc7518#section-3.1 } Link to RFC}

  - [RS256] and [HS256] and none is currently the only supported algs for signature
  - [RSA_OAEP] is currently the only supported alg for encryption

  *)

  val alg_to_string : alg -> string

  val alg_of_string : string -> alg

  val alg_to_json : alg -> Yojson.Safe.t

  val alg_of_json : Yojson.Safe.t -> alg

  (** {{: https://tools.ietf.org/html/rfc7518#section-6.1 } Link to RFC } *)
  type kty =
    [ `oct  (** Octet sequence (used to represent symmetric keys) *)
    | `RSA  (** RSA {{: https://tools.ietf.org/html/rfc3447} Link to RFC} *)
    | `EC  (** Elliptic Curve *) ]

  val kty_to_string : kty -> string

  val kty_of_string : string -> kty

  (** {{: https://tools.ietf.org/html/rfc7518#section-5 } Link to RFC}*)
  type enc =
    | A128CBC_HS256
        (** AES_128_CBC_HMAC_SHA_256 authenticated encryption algorithm, https://tools.ietf.org/html/rfc7518#section-5.2.3 *)
    | A256CBC_HS512
        (** AES_256_CBC_HMAC_SHA_512 authenticated encryption algorithm, https://tools.ietf.org/html/rfc7518#section-5.2.5 *)
    | A256GCM  (** AES GCM using 256-bit key *)

  val enc_to_string : enc -> string

  val enc_of_string : string -> enc
end

(**
{1 JSON Web Key}

{{: https://tools.ietf.org/html/rfc7517 } Link to RFC }
*)
module Jwk : sig
  (** [use] will default to [`Sig] in all functions unless supplied *)
  type use = [ `Sig | `Enc | `Unsupported of string ]

  val use_to_string : use -> string

  val use_of_string : string -> use

  type public = Public

  type priv = Private

  type 'key jwk = {
    alg : Jwa.alg;  (** The algorithm for the key *)
    kty : Jwa.kty;  (** The key type for the key *)
    use : use;
    key : 'key;  (** The key implementation *)
  }

  (** [rsa] represents a public JWK with [kty] [`RSA] and a [Rsa.pub] key *)
  type pub_rsa = Mirage_crypto_pk.Rsa.pub jwk

  (** [rsa] represents a private JWK with [kty] [`RSA] and a [Rsa.priv] key *)
  type priv_rsa = Mirage_crypto_pk.Rsa.priv jwk

  (** [oct] represents a JWK with [kty] [`OCT] and a string key.

  [oct] will in most cases be a private key but there are some cases where it will be considered public, eg. if you parse a public JSON *)
  type oct = string jwk

  (**
    [t] describes a JSON Web Key which can be either [public] or [private]
    *)
  type 'a t =
    | Oct : oct -> 'a t
    | Rsa_priv : priv_rsa -> priv t
    | Rsa_pub : pub_rsa -> public t

  (**
  {1 Public keys}
  These keys are safe to show and should be used to verify signed content.
  *)

  val make_pub_rsa : ?use:use -> Mirage_crypto_pk.Rsa.pub -> public t
  (**
    [rsa_of_pub use pub] takes a public key generated by Nocrypto and returns a result t or a message of what went wrong.
    *)

  val of_pub_pem :
    ?use:use -> string -> (public t, [> `Msg of string | `Not_rsa ]) result
  (**
    [of_pub_pem use pem] takes a PEM as a string and returns a [public t] or a message of what went wrong.
    *)

  val to_pub_pem : 'a t -> (string, [> `Msg of string | `Not_rsa ]) result
  (**
    [to_pub_pem t] takes a JWK and returns a result PEM string or a message of what went wrong.
    *)

  val of_pub_json :
    Yojson.Safe.t ->
    ( public t,
      [> `Json_parse_failed of string
      | `Msg of string
      | `Unsupported_kty
      | `Missing_use_and_alg ] )
    result
  (**
    [of_pub_json t] takes a [Yojson.Safe.t] and tries to return a [public t] 
    *)

  val of_pub_json_string :
    string ->
    ( public t,
      [> `Json_parse_failed of string
      | `Msg of string
      | `Unsupported_kty
      | `Missing_use_and_alg ] )
    result
  (**
    [of_pub_json_string json_string] takes a JSON string representation and tries to return a [public t]
    *)

  val to_pub_json : 'a t -> Yojson.Safe.t
  (**
    [to_pub_json t] takes a [priv t] and returns a JSON representation
    *)

  val to_pub_json_string : 'a t -> string
  (**
    [to_pub_json_string t] takes a [priv t] and returns a JSON string representation
    *)

  (**
  {1 Private keys}

  These keys are not safe to show and should be used to sign content.
  *)

  val make_priv_rsa : ?use:use -> Mirage_crypto_pk.Rsa.priv -> priv t
  (**
    [make_priv_rsa use priv] takes a private key generated by Nocrypto and returns a priv t or a message of what went wrong.
    *)

  val of_priv_pem :
    ?use:use -> string -> (priv t, [> `Msg of string | `Not_rsa ]) result
  (**
    [of_priv_pem use pem] takes a PEM as a string and returns a [priv t] or a message of what went wrong.
    *)

  val make_oct : ?use:use -> string -> priv t
  (**
    [make_oct use secret] creates a [priv t] from a shared secret
    *)

  val to_priv_pem : priv t -> (string, [> `Msg of string | `Not_rsa ]) result
  (**
    [to_priv_pem t] takes a JWK and returns a result PEM string or a message of what went wrong.
    *)

  val of_priv_json :
    Yojson.Safe.t ->
    ( priv t,
      [> `Json_parse_failed of string
      | `Msg of string
      | `Unsupported_kty
      | `Missing_use_and_alg ] )
    result
  (**
    [of_json json] takes a [Yojson.Safe.t] and returns a [priv t]
    *)

  val of_priv_json_string :
    string ->
    ( priv t,
      [> `Json_parse_failed of string
      | `Msg of string
      | `Unsupported_kty
      | `Missing_use_and_alg ] )
    result
  (**
    [of_priv_json_string json_string] takes a JSON string representation and tries to return a [private t]
    *)

  val to_priv_json : priv t -> Yojson.Safe.t
  (**
    [to_json t] takes a [t] and returns a [Yojson.Safe.t]
    *)

  val to_priv_json_string : priv t -> string
  (**
    [to_priv_json_string t] takes a [priv t] and returns a JSON string representation
    *)

  (**
  {1 Utils }
  Utils to get different data from a JWK
  *)

  val get_kid : 'a t -> string
  (** [get_kid jwk] is a convencience function to get the kid string *)

  val get_kty : 'a t -> Jwa.kty
  (** [get_kty jwk] is a convencience function to get the key type *)

  val get_alg : 'a t -> Jwa.alg
  (** [get_alg jwk] is a convencience function to get the algorithm *)
end

(**
{1 JSON Web Key Set}

{{: https://tools.ietf.org/html/rfc7517#section-5 } Link to RFC }
*)
module Jwks : sig
  (**  [t] describes a Private JSON Web Key Set *)
  type t = { keys : Jwk.public Jwk.t list }

  val to_json : t -> Yojson.Safe.t
  (**
  [to_json t] takes a [t] and returns a [Yojson.Safe.t]
  *)

  val of_json : Yojson.Safe.t -> t
  (**
  [of_json json] takes a [Yojson.Safe.t] and returns a [t].
  Keys that can not be serialized safely will be removed from the list
  *)

  val of_string : string -> t
  (**
    [of_string json_string] takes a JSON string representation and returns a [t].
    Keys that can not be serialized safely will be removed from the list
    *)

  val to_string : t -> string
  (**
  [to_string t] takes a t and returns a JSON string representation
  *)

  val find_key : t -> string -> Jwk.public Jwk.t option
end

module Header : sig
  (**
    The [header] has the following properties:
    - [alg] Jwa - RS256 and none is currently the only supported algs
    - [jku] JWK Set URL
    - [jwk] JSON Web Key
    - [kid] Key ID - We currently always expect this to be there, this can change in the future
    - [x5t] X.509 Certificate SHA-1 Thumbprint
    - [x5t#S256] X.509 Certificate SHA-256 Thumbprint
    - [typ] Type
    - [cty] Content Type
    Not implemented:
    - [x5u] X.509 URL
    - [x5c] X.509 Certficate Chain
    - [crit] Critical

    {{: https://tools.ietf.org/html/rfc7515#section-4.1 } Link to RFC }
    *)
  type t = {
    alg : Jwa.alg;
    jku : string option;
    jwk : Jwk.public Jwk.t option;
    kid : string;
    x5t : string option;
    x5t256 : string option;
    typ : string option;
    cty : string option;
    enc : Jwa.enc option;
  }

  val make_header : ?typ:string -> Jwk.priv Jwk.t -> t
  (**
  [make_header jwk] creates a header with [typ], [kid] and [alg] set based on the public JWK
  *)

  val of_string : string -> (t, [> `Msg of string ]) result

  val to_string : t -> (string, [> `Msg of string ]) result

  val to_json : t -> Yojson.Safe.t

  val of_json : Yojson.Safe.t -> (t, [> `Msg of string ]) result
end

(**
  {1 JSON Web Signature}

  {{: https://tools.ietf.org/html/rfc7515 } Link to RFC }
*)
module Jws : sig
  type signature = string

  type t = { header : Header.t; payload : string; signature : signature }

  val of_string : string -> (t, [> `Msg of string ]) result

  val to_string : t -> (string, [> `Msg of string ]) result

  val validate :
    jwk:'a Jwk.t -> t -> (t, [> `Invalid_signature | `Msg of string ]) result
  (**
  [validate jwk t] validates the signature
  *)

  val sign :
    header:Header.t ->
    payload:string ->
    Jwk.priv Jwk.t ->
    (t, [> `Msg of string ]) result
  (**
  [sign header payload priv] creates a signed JWT from [header] and [payload]

  We will start using a private JWK instead of a Mirage_crypto_pk.Rsa.priv soon
  *)
end

(**
{1 JSON Web Token}
*)
module Jwt : sig
  type payload = Yojson.Safe.t

  type claim = string * Yojson.Safe.t

  val empty_payload : payload

  type t = { header : Header.t; payload : payload; signature : Jws.signature }

  val add_claim : string -> Yojson.Safe.t -> payload -> payload

  val to_string : t -> (string, [> `Msg of string ]) result

  val of_string : string -> (t, [> `Msg of string ]) result

  val to_jws : t -> Jws.t

  val of_jws : Jws.t -> t

  val validate :
    jwk:'a Jwk.t ->
    t ->
    (t, [> `Expired | `Invalid_signature | `Msg of string ]) result
  (**
  [validate jwk t] checks if the JWT is valid and then calls Jws.validate to validate the signature
  *)

  val sign :
    header:Header.t ->
    payload:payload ->
    Jwk.priv Jwk.t ->
    (t, [> `Msg of string ]) result
  (**
  [sign header payload priv] creates a signed JWT from [header] and [payload]

  We will start using a private JWK instead of a Mirage_crypto_pk.Rsa.priv soon
  *)
end

module Jwe : sig
  (** {{: https://tools.ietf.org/html/rfc7516 } Link to RFC } *)

  (** Additional Authentication Data *)
  type aad

  (** JWE Protected Header *)
  type protected

  type t = {
    header : Header.t;
    cek : string;
    init_vector : string;
    payload : string;
    aad : aad option;
  }

  val encrypt : ?protected:'a -> string -> jwk:Jwk.priv Jwk.t -> string

  val decrypt :
    string ->
    jwk:Jwk.priv Jwk.t ->
    ( t,
      [> `Invalid_JWE | `Invalid_JWK | `Decrypt_cek_failed | `Msg of string ]
    )
    result
end
