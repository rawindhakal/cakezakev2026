<?php
namespace App\Helpers;

use Illuminate\Support\Facades\Log;

class Paystack
{
	private $secret_key,$public_key,$curl;
	public $temp = array();
    private $url;

    function __construct($gateways = null)
    {
        $g = is_array($gateways) ? $gateways : [];
        $this->secret_key = $g['paystack_secret_key'] ?? '';
		$this->public_key = $g['paystack_public_key'] ?? '';
        $this->url = "https://api.paystack.co/";

        Log::info("URL : ".$this->url);
    }

	public function transfer($data){
		$end_point = $this->url."transfer";
		$method = "post";

		$transfer = $this->curl_request($end_point,$method,$data);
		return $transfer;
	}

    public function verify_transaction($reference = ''){
		$end_point = $this->url."transaction/verify";
		$end_point .= (!empty($reference))?"/".$reference:"";
		$method = "get";
		$transfer = $this->curl_request($end_point,$method);
		return $transfer;
	}
	public function curl_request($end_point,$method,$data = array()){
		$this->curl = curl_init();

		curl_setopt_array($this->curl, array(
			CURLOPT_URL => $end_point,
			CURLOPT_RETURNTRANSFER => true,
			CURLOPT_CUSTOMREQUEST => strtoupper($method),
			CURLOPT_POSTFIELDS => $data,   /* array('test_key' => 'test_value_1') */
			CURLOPT_HTTPHEADER => array(
				"Authorization: Bearer ".$this->secret_key
			),
		));

		$response = curl_exec($this->curl);
		unset($this->curl);

		return $response;
	}
}
?>
