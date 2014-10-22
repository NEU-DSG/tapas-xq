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
    $connector = new TapasHydraConnector();
    $connector->_validate_tei($fpath); 
  }

  function _validate_tei($fpath){
    $connection = $this->base_url."files/validate_tei.json";

    $result = $this->post_request($connection, $fpath);
    return $result;
  }

  private function post_request($connection, $fpath, $data = array()){
    $file         = $this->create_curl_file_field($fpath);
    $content_type = (new Finfo(FILEINFO_MIME))->file($fpath);
    $data         = array_merge($this->default_opts, $data);
    $data["file"] = $file;

    $curl = curl_init($connection);
    curl_setopt($curl, CURLOPT_POSTFIELDS, $data);
    return curl_exec($curl);
  }

  private function create_curl_file_field($fpath){
    return "@".$fpath.";filename=".pathinfo($fpath)['basename'];
  }
}