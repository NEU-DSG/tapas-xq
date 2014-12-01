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

  static function create_collection($node, $depositor) {
    (new TapasHydraConnector())->_create_collection($node, $depositor);
  }

  static function create_group($node, $depositor) { 
    (new TapasHydraConnector())->_create_group($node, $depositor);
  }

  static function update_group($node, $args) { 
    return (new TapasHydraConnector())->_update_group($node, $args);
  }

  static function validate_tei($fpath){
    return (new TapasHydraConnector())->_validate_tei($fpath);
  }

  static function create_file($node, $depositor){
    return (new TapasHydraConnector())->_create_file($node, $depositor);
  }

  function _create_group($node, $depositor) {
    $data = [];

    $data["nid"] = $node->nid;
    $data["depositor"] = $depositor->uid;

    if($node->title) { $data["title"] = $node->title; }

    # This is coerced into looking like an array because Rails expects 
    # a multi-valued object for the [:members] field.  However, at the time
    # that hook_node_submit is invoked (e.g. at project creation, when this create_group
    # method is invoked) no user->project relationships beyond that defined by $node->uid exist/
    # can exist/are accessible.  Note that $node->uid indicates the onwer/administrator 
    # of the project.
    $data["members["."0"."]"] = $node->uid;

    $connection = $this->base_url."communities.json";

    $response = $this->post_request($connection, $data);
    $this->handle_response_quietly($response);
  }

  function _update_group($node, $args) {
    # Recompute group membership conditionally
    if ($args["membership_changed"]) {
      $members = $this->group_membership($node);
      foreach($members as $i => $member) {
        $data["members["."$i"."]"] = $member;
      }
    }

    $connection = $this->base_url."communities/nid/$node->nid";
    $response = $this->put_request($connection, $data);
    $this->handle_response_quietly($response);
  }

  function _create_collection($node, $depositor) { 
    $data = [];

    $data["nid"] = $node->nid;
    $data["depositor"] = $depositor->uid;
    $data["project"] = $node->og_group_ref['und'][0]['target_id'];

    if($node->title) { $data["title"] = $node->title; }
    
    $connection = $this->base_url."collections.json";

    $response = $this->post_request($connection, $data);
    $this->handle_response_quietly($response);
  }
  
  function _validate_tei($fpath){
    $connection = $this->base_url."files/validate_tei.json";
    return $this->post_request($connection, ["file" => $fpath]);
  }

  function _create_file($node, $depositor){
    $filepath = drupal_realpath($node->field_tei_xml['und'][0]['uri']);
    if(!$filepath){
      $e = "Attempted to get the file uri of node $node->nid - no uri found";
      return $this->watchdog_and_error($e, 2);
    } else {
      $data["file"] = $filepath;
    }

    # Get item node id
    if ($node->nid == null){
      $e = "Somehow attempted to upload file with no node id?  " + 
           "Non-node associated with file currently existing at $filepath";
      return $this->watchdog_and_error($e, 2);
    } else { 
      $data["nid"] = $node->nid;
    }

    # Get depositor's email address.
    if (! $depositor->uid){
      $e = "Something went wrong when accessing file depositor's uid.";
      return $this->watchdog_and_error($e, 2);
    } else {
      $data["depositor"]   = $depositor->uid;
    }

    # Get collection nid.
    $collection_id = $node->field_collection_node_reference['und'][0]['target_id'];
    if ($collection_id == null) {
      $e = "Attempted to upload a file that belongs to no collection, see node ".
           "$node->nid";
      return $this->watchdog_and_error($e, 2);
    } else { 
      $data["collection"] = $collection_id;
    }

    $connection = $this->base_url."files";
    $response   = $this->post_request($connection, $data);
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

  private function put_request($connection, $data = array()) {
    $data = array_merge($this->default_opts, $data);

    # If a file must be sent, prepare make it cURL transfer ready at this step
    if ($data['file']) {
      $data['file'] = $this->create_curl_file_field($data['file']);
    }

    $curl_options = array(CURLOPT_RETURNTRANSFER => 1,
      CURLOPT_CUSTOMREQUEST => "PUT",
      CURLOPT_POSTFIELDS => $data);

    return $this->http_request($connection, $curl_options);
  }

  private function post_request($connection, $data = array()){
    $data = array_merge($this->default_opts, $data);

    if ($data['file']) {
      $data['file'] = $this->create_curl_file_field($data['file']);
    }

    $curl_options = array(CURLOPT_RETURNTRANSFER => 1, 
                          CURLOPT_POSTFIELDS => $data);

    return $this->http_request($connection, $curl_options);
  }

  private function http_request($connection, $curl_opts) {
    $curl = curl_init($connection);
    curl_setopt_array($curl, $curl_opts);

    $response = curl_exec($curl);

    if ($response == false) {
      $error_body = "cURL attempt in TapasHydraConnector threw ".
                    "the following error: ".curl_error($curl);
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
