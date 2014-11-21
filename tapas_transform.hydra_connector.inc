<?php 
/**
 * @file 
 * Implements an encapsulating class for connections to the tapas_hydra 
 * head and functions on top of it for preparing certain operations that 
 * this module should be offloading to that head.
 */
class TapasHydraConnector { 
  private $base_url;
  private $email;
  private $api_token;
  private $default_opts;

  function __construct(){
    $this->base_url     = variable_get("tapas_hydra_base_url");
    $this->email        = variable_get("tapas_hydra_email");
    $this->api_token    = variable_get("tapas_hydra_api_token");
    $this->default_opts = array("email" => $this->email, 
                                "token" => $this->api_token);
  }

  function inspect_connection_info(){
    echo "Tapas Hydra base url is: ".$this->base_url."\n";
    echo "email to use is: ".$this->email."\n";
    echo "API key not echoed \n";
  }

  // CRUD functions for collections/communities (groups)

  static function create_collection($node) {
    (new TapasHydraConnector())->_create_collection($node);
  }

  static function create_group($node) { 
    (new TapasHydraConnector())->_create_group($node);
  }

  function _create_group($node) {
    $data = [];

    $data["nid"] = $node->nid;

    if($node->title) { $data["title"] = $node->title; }

    $desc = $node->body['und'][0]['safe_value'];
    if ($desc) { $data["description"] = $desc; } 

    $members = $this->group_membership($node);
    foreach ($members as $i => $member) {
      $data["members[".$i."]"] = $member;
    }

    $connection = $this->base_url."communities.json";

    $response = $this->post_request($connection, null, $data);
    $this->handle_response_quietly($response);
  }

  function _create_collection($node) { 

  }

  // Slightly less clean code for saving/generating files
  static function validate_tei($fpath){
    return (new TapasHydraConnector())->_validate_tei($fpath);
  }

  static function save_file_to_hydra($node, $depositing_user){
    return (new TapasHydraConnector())->_save_file_to_hydra($node, $depositing_user);
  }

  function _validate_tei($fpath){
    $connection = $this->base_url."files/validate_tei.json";
    return $this->post_request($connection, $fpath);
  }

  function _save_file_to_hydra($node, $depositing_user){
    $filepath = drupal_realpath($node->field_tei_xml['und'][0]['uri']);
    if(!$filepath){
      $e = "Attempted to get the file uri of node $node->nid - no uri found";
      return $this->watchdog_and_error($e, 2);
    }

    # Get item node id
    if ($node->nid == null){
      $e = "Somehow attempted to upload file with no node id?  " + 
           "Non-node associated with file currently existing at $filepath";
      return $this->watchdog_and_error($e, 2);
    } else { 
      $data["node_id"] = $node->nid;
    }

    # Get depositor's email address.
    if (! $depositing_user->mail){
      $e = "Attempted to deposit as a user with no email address.  UID was ".
           "$depositing_user->uid";
      return $this->watchdog_and_error($e, 2);
    } else {
      $data["depositor"]   = $depositing_user->mail;
    }

    # Get collection nid.
    $collection_id = $node->field_collection_node_reference['und'][0]['target_id'];
    if ($collection_id == null) {
      $e = "Attempted to upload a file that belongs to no collection, see node ".
           "$node->nid";
      return $this->watchdog_and_error($e, 2);
    } else { 
      $data["collection_id"] = $collection_id;
    }

    $connection = $this->base_url."files";
    $response   = $this->post_request($connection, $filepath, $data);
    $this->handle_response_quietly($response);
  }

  // Every interaction with the hydra server besides TEI file validation should
  // not indicate to the end user in any way what did/didn't happen.  This 
  // method handles kicking off watchdog errors where appropriate for those 
  // interactions.  Note that we don't do anything in the case where the response is 
  // false or null - we assume this is a cURL error and allow post_request (or other 
  // methods that should have access to the curl request) handle it.
  private function handle_response_quietly($response) { 
    if ($response && ($response->status_code == 500)) {
      $m = "Repository responded with 500 error - check repository status.";
      $this->watchdog_and_error($m, 2);
    } elseif ($response && ($response->status_code == 422)) {
      $errors = implode(" ; ", $response->errors);
      $m = "Invalid interaction attempted with server! Errors were: $errors";
      $this->watchdog_and_error($m, 2);
    }
  }

  private function post_request($connection, $fpath, $data = array()){
    $data = array_merge($this->default_opts, $data);
    if ($fpath) { $data["file"] = $this->create_curl_file_field($fpath); }

    $curl_options = array(CURLOPT_RETURNTRANSFER => 1, 
                          CURLOPT_POSTFIELDS => $data);

    $curl = curl_init($connection);
    curl_setopt_array($curl, $curl_options);

    $response = curl_exec($curl);

    # If the response is false, we assume a curl error was thrown
    if ($response == false){
      $error_body  = "cURL attempt in TapasHydraConnector threw ".
                     "following error: ".curl_error($curl);
      return $this->watchdog_and_error($error_body, 2);
    } else {  
      $response = json_decode($response);
      $response->status_code = curl_getinfo($curl, CURLINFO_HTTP_CODE);
      return $response;
    }
  }

  private function create_curl_file_field($fpath){
    return "@".$fpath.";filename=".pathinfo($fpath)['basename'];
  }

  private function watchdog_and_error($message, $error_level){
    watchdog("tapas_transform", $message, array(), $error_level);
    return false;
  }

  // Return a list of uids associated with this group.
  function group_membership($node) {
    $nid = $node->nid;

    $query = db_select("og_membership", "ogm")
      ->fields("ogm", ["etid"])
      ->condition("ogm.gid", $nid)
      ->condition("ogm.entity_type", "user");

    $result = $query->execute();

    $result = $result->fetchCol();
    return $result;
  }  
}
