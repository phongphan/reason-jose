let () = Mirage_crypto_rng_unix.initialize ()

open Helpers

let jwt_suite, _ =
  Junit_alcotest.run_and_report ~package:"jose" "JWT"
    [
      ( "JWT",
        [
          Alcotest.test_case "Can validate a RSA256 JWT" `Quick (fun () ->
              let open Jose in
              let jwk =
                JwkP.of_pub_pem Fixtures.rsa_test_pub |> CCResult.get_exn
              in
              let jwt =
                Jwt.of_string Fixtures.external_jwt_string
                |> CCResult.flat_map (Jwt.validate ~jwk)
                |> CCResult.get_exn
              in
              check_string "correct payload" {|{"sub":"tester"}|}
                (Yojson.Safe.to_string jwt.payload));
          Alcotest.test_case "Can validate a HS256 JWT" `Quick (fun () ->
              let open Jose in
              let jwk = JwkP.make_oct Fixtures.oct_key_string in
              let jwt =
                Jwt.of_string Fixtures.oct_jwt_string
                |> CCResult.flat_map (Jwt.validate ~jwk)
                |> CCResult.get_exn
              in
              check_string "correct payload" {|{"sub":"tester"}|}
                (Yojson.Safe.to_string jwt.payload));
          Alcotest.test_case "Can create a JWT with RSA256" `Quick (fun () ->
              let open Jose in
              let jwk =
                JwkP.of_priv_pem Fixtures.rsa_test_priv |> CCResult.get_exn
              in
              let header : Jose.Header.t = Header.make_header ~typ:"JWT" jwk in
              check_string "Header is correct"
                {|{"typ":"JWT","alg":"RS256","kid":"0IRFN_RUHUQcXcdp_7PLBxoG_9b6bHrvGH0p8qRotik"}|}
                (Header.to_json header |> Yojson.Safe.to_string);
              check_string "alg is correct" "RS256"
                ( Header.to_json header
                |> Yojson.Safe.Util.member "alg"
                |> Yojson.Safe.Util.to_string );
              let payload =
                Jwt.empty_payload |> Jwt.add_claim "sub" (`String "tester")
              in
              let jwt_r = Jwt.sign ~header:(Obj.magic header) ~payload jwk in
              check_result_string "JWT is correctly created"
                (Ok Fixtures.external_jwt_string)
                (CCResult.flat_map Jwt.to_string jwt_r));
          Alcotest.test_case "Can create a JWT with HS256" `Quick (fun () ->
              let open Jose in
              let header =
                Header.make_header ~typ:"JWT"
                  (JwkP.make_oct Fixtures.oct_key_string)
              in
              check_string "Header is correct"
                {|{"typ":"JWT","alg":"HS256","kid":"J4xQh7z-EaJI7Py1P4rFf2S0rppP2m4yKrZW4X4Yfuk"}|}
                (Header.to_json header |> Yojson.Safe.to_string);
              check_string "alg is correct" "HS256"
                ( Header.to_json header
                |> Yojson.Safe.Util.member "alg"
                |> Yojson.Safe.Util.to_string );
              let payload =
                Jwt.empty_payload |> Jwt.add_claim "sub" (`String "tester")
              in
              let jwk = JwkP.make_oct Fixtures.oct_key_string in
              let jwt_r = Jwt.sign ~header:(Obj.magic header) ~payload jwk in
              check_result_string "JWT is correctly created"
                (Ok Fixtures.oct_jwt_string)
                (CCResult.flat_map Jwt.to_string jwt_r));
          Alcotest.test_case "Can validate my own RSA JWT" `Quick (fun () ->
              let open Jose in
              let jwk =
                JwkP.of_priv_pem Fixtures.rsa_test_priv |> CCResult.get_exn
              in
              let header = Header.make_header ~typ:"JWT" jwk in
              let payload =
                Jwt.empty_payload |> Jwt.add_claim "sub" (`String "tester")
              in
              let jwt_r =
                Jwt.sign ~header:(Obj.magic header) ~payload jwk
                |> CCResult.flat_map (Jwt.validate ~jwk)
              in
              check_result_string "JWT is correctly created"
                (Ok Fixtures.external_jwt_string)
                (CCResult.flat_map Jwt.to_string jwt_r));
          Alcotest.test_case "Can validate my own OCT JWT" `Quick (fun () ->
              let open Jose in
              let header =
                Header.make_header ~typ:"JWT"
                  (Jose.JwkP.make_oct ~use:"sign" Fixtures.oct_key_string)
              in
              let payload =
                Jwt.empty_payload |> Jwt.add_claim "sub" (`String "tester")
              in
              let jwk = JwkP.make_oct Fixtures.oct_key_string in
              let jwt_r =
                Jwt.sign ~header:(Obj.magic header) ~payload jwk
                |> CCResult.flat_map (Jwt.validate ~jwk)
              in
              check_result_string "JWT is correctly created"
                (Ok Fixtures.oct_jwt_string)
                (CCResult.flat_map Jwt.to_string jwt_r));
        ] );
    ]

let jwt_suite = jwt_suite
