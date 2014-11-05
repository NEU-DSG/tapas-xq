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

  static function validate_tei($fpath){
    return (new TapasHydraConnector())->_validate_tei($fpath);
  }

  // Grab the file associated with this node and save it to Hydra
  // Returns a JSON hash of URI's for the three transforms that 
  // are actually useful for TAPAS.
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

    $data   = ["depositor" => $depositing_user->mail];
    if ($data["depositor"] == null){
      $e = "Attempted to deposit as a user with no email address.  UID was ".
           "$depositing_user->uid";
      return $this->watchdog_and_error($e, 2);
    }

    $collection_id = $node->field_collection_node_reference['und'][0]['target_id'];
    if ($collection_id == null) {
      $e = "Attempted to upload a file that belongs to no collection, see node ".
           "$node->nid";
      return $this->watchdog_and_error($e, 2);
    }

    $data[] = ["collection" => $collection_id];

    $connection = $this->base_url."files";
    return $this->post_request($connection, $filepath, $data);
  }

  private function post_request($connection, $fpath, $data = array()){
    $data         = array_merge($this->default_opts, $data);
    $data["file"] = $this->create_curl_file_field($fpath);

    $curl_options = array(CURLOPT_RETURNTRANSFER => 1, 
                          CURLOPT_POSTFIELDS => $data);

    $curl = curl_init($connection);
    curl_setopt_array($curl, $curl_options);

    $response = curl_exec($curl);

    # If the response is false, we assume a curl error was thrown
    if ($response == false){
      $error_body  = "cURL attempt in TapasHydraConnector threw ".
                     "following error: ".curl_error($curl);
      return watchdog_and_error($error_body, 2);
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
}