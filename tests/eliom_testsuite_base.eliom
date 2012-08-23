

{shared{
  open Eliom_content
  open Eliom_lib
}}

module My_appl =
  Eliom_registration.App (
    struct
      let application_name = "eliom_testsuite"
    end)

let main = Eliom_service.service [] Eliom_parameter.unit ()

let tests description services =
  Html5.F.(
    div [
      h4 [pcdata description];
      ul
        (List.map
           (fun (description, service) ->
              li [a ~service [pcdata description] ()])
           services);
    ]
  )

let testsuite ~name testsuite_tests =
  Html5.F.(
    div
      (h3 [pcdata name] ::
       List.map (uncurry tests) testsuite_tests)
  )

let test_logger =
  Html5.D.(div ~a:[a_class ["test_logger"]] [h4 [pcdata "Client logger"]])

let test ~path ~title:ttl ~description f =
  ignore {unit{
    Lwt.ignore_result
      (lwt () = Eliom_client.wait_load_end () in
       Dom.appendChild
         (Html5.To_dom.of_div (Html5.F.(div [pcdata "test"])))
         (Html5.To_dom.of_div %test_logger)
         ;
       Lwt.return ())
  }};
  ttl, My_appl.register_service
           ~path
           ~get_params:Eliom_parameter.unit
           (fun () () ->
              lwt content = f () in
              Lwt.return
                Html5.F.(html
                           (Eliom_tools.Html5.head
                              ~title:(String.concat "/" path)
                              ~css:[["style.css"]] ())
                           (body
                              (p [a ~xhr:false ~service:main [pcdata "Home and break app"] ()] ::
                               p [a ~service:Eliom_service.void_coservice' [pcdata "Reload in running app"] ()] ::
                               h1 ~a:[a_class ["test_title"]] [pcdata ttl] ::
                               div ~a:[a_class ["test_description"]] description ::
                               content @
                               [test_logger]))))

{client{

  let buffer = ref []
  let append_log_message msg =
    trace "append_log_message %s" msg;
    Html5.Manip.appendChild
      %test_logger
      Html5.D.(div ~a:[a_class ["logging_line"]] [pcdata msg])
  let () =
    Lwt.ignore_result
      (lwt () = Eliom_client.wait_load_end () in
(*
       Html5.Manip.appendChild
         (Html5.Of_dom.of_element Dom_html.document##body)
         %test_logger;
 *)
       List.iter append_log_message (List.rev !buffer);
       buffer := [];
       Lwt.return ())
  let log : 'a . ('a, unit, string, unit) format4 -> 'a =
    fun fmt ->
      Printf.ksprintf
        (fun msg ->
           if Eliom_client.in_onload ()
           then buffer := msg :: !buffer
           else append_log_message msg)
        fmt

}}

let failed_assertions : string list Eliom_reference.Volatile.eref =
  Eliom_reference.Volatile.eref ~scope:Eliom_common.request []
let ran_assertions : string list Eliom_reference.Volatile.eref =
  Eliom_reference.Volatile.eref ~scope:Eliom_common.request []

let get_failed_assertions () =
  Eliom_reference.Volatile.get failed_assertions
let get_ran_assertions () =
  Eliom_reference.Volatile.get ran_assertions

let assert_equal ?(eq=(=)) ~name value should_be =
  Eliom_reference.Volatile.modify ran_assertions
    (fun names -> name :: names);
  if not (eq value should_be) then
    Eliom_reference.Volatile.modify failed_assertions
      (fun names -> name :: names)
  else
    debug "Test %s ok" name

{client{
  let assert_equal ?(eq=(=)) ~name value should_be =
    if not (eq value should_be) then
      log "ASSERT EQUAL FAIL: %s" name
    else
      log "Test %s ok" name
}}
