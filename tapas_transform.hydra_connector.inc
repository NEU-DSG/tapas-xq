<?php 

/**
 * @file 
 * Implements an encapsulating class for connections to the tapas_hydra 
 * head and functions on top of it for preparing certain operations that 
 * this module should be offloading to that head.
 */
class TapasHydraConnector { 
  private $base_url;
  private $username;
  private $user_api_key;

  function __construct(){
    $this->base_url     = variable_get("tapas_hydra_base_url");
    $this->username     = variable_get("tapas_hydra_username");
    $this->user_api_key = variable_get("tapas_hydra_api_key");
  }

  function inspect_connection_info(){
    echo "Tapas Hydra base url is: ".$this->base_url."\n";
    echo "Username to use is: ".$this->username."\n";
    echo "API key not echoed \n";
  }

  static function validate_tei($fpath){
    $connector = new TapasHydraConnector();
    $connector->_validate_tei($fpath); 
  }

  function _validate_tei($fpath){
    $connection = $this->base_url."files/validate_tei.json";

    $result = $this->post_request($connection, $fpath);
  }

  private function post_request($connection, $fpath, $data = null){
    $file = $this->create_curl_file_field($fpath);
  }

  private function create_curl_file_field($fpath){
    $file_name = pathinfo($fpath);
    $file_name = $file_name["basename"];

    $file_mime = new Finfo(FILEINFO_MIME);
    $file_mime = $file_mime->finfo($fpath);
  }
}