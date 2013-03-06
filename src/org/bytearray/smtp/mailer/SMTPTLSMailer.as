/*_____ __  __ _______ _____  __  __       _ _
 / ____|  \/  |__   __|  __ \|  \/  |     (_) |
| (___ | \  / |  | |  | |__) | \  / | __ _ _| | ___ _ __
 \___ \| |\/| |  | |  |  ___/| |\/| |/ _` | | |/ _ \ '__|
 ____) | |  | |  | |  | |    | |  | | (_| | | |  __/ |
|_____/|_|  |_|  |_|  |_|    |_|  |_|\__,_|_|_|\___|_|
/*
* This class lets you send rich emails with AS3 (html, attached files) through SMTP
* for more infos http://en.wikipedia.org/wiki/Simple_Mail_Transfer_Protocol
* @author Thibault Imbert (bytearray.org)
* @version 0.3 Added image type auto detect (PNG, JPG-JPEG)
* @version 0.4 Dispatching proper events
* @version 0.5 Handles every kind of files for attachment, few bugs fixed
* @version 0.6 Handles authentication, thank you Wein ;)
* @version 0.7 Few fixes, thank you Vicente ;)
* @version 0.8 Good fix, thank you Ben and Carlos ;)
* @version 0.9 Refactoring ;)
*/

package org.bytearray.smtp.mailer {
	import com.hurlant.crypto.tls.TLSConfig;
	import com.hurlant.crypto.tls.TLSEngine;
	import com.hurlant.crypto.tls.TLSError;
	import com.hurlant.crypto.tls.TLSSocket;
	
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	import flash.utils.getTimer;
	
	import mx.rpc.events.ResultEvent;
	import mx.utils.StringUtil;
	
	import org.bytearray.smtp.crypto.MD5;
	import org.bytearray.smtp.encoding.Base64;
	import org.bytearray.smtp.events.SMTPEvent;
	import org.bytearray.smtp.infos.SMTPInfos;

	[Event(name = "mailSent", type = "org.bytearray.smtp.events.SMTPEvent")]
	[Event(name = "authenticated", type = "org.bytearray.smtp.events.SMTPEvent")]
	[Event(name = "mailError", type = "org.bytearray.smtp.events.SMTPEvent")]
	[Event(name = "badSequence", type = "org.bytearray.smtp.events.SMTPEvent")]
	[Event(name = "connected", type = "org.bytearray.smtp.events.SMTPEvent")]
	[Event(name = "disconnected", type = "org.bytearray.smtp.events.SMTPEvent")]
	[Event(name = "error", type = "org.bytearray.smtp.events.SMTPEvent")]
	public class SMTPTLSMailer extends TLSSocket implements ISMTPMailer {
		private var sHost:String;

		private var sPort:int;

		private var buffer:Array = new Array();

		private var sLogin:String, sPass:String;

		// regexp pattern
		private var reg:RegExp = /^\d{3}/img;

		// PNG, JPEG header values
		private static const PNG:Number = 0x89504E47;

		private static const JPEG:Number = 0xFFD8;

		// common SMTP server response codes
		// other codes could be added to add fonctionalities and more events
		private static const ACTION_OK:Number = 250;

		private static const AUTHENTICATED:Number = 235;

		private static const DISCONNECTED:Number = 221;

		private static const READY:Number = 220;

		private static const DATA:Number = 354;

		private static const BAD_SEQUENCE:Number = 503;

		private static const AUTH_DETAILS:Number = 334;

		private static const ERROR_CODES:Array = [ 500, 501, 502, 503, 504, 521, 530, 535, 550, 551, 552, 553, 554 ];


		public function SMTPTLSMailer(pHost:String, pPort:int) {
			try {
				super();
				var config:TLSConfig = new TLSConfig(TLSEngine.CLIENT);
				super.connect(pHost, pPort, config);
				sHost = pHost;
				sPort = pPort;

				addEventListener(ProgressEvent.SOCKET_DATA, socketDataHandler);
				addEventListener(IOErrorEvent.IO_ERROR, errorHandler);
			} catch (tls:TLSError) {
				dispatchEvent(new SMTPEvent(SMTPEvent.MAIL_ERROR, tls.message));
			}
		}

		/*
		* This method lets you authenticate, just pass a login and password
		*/

		public function get password():String {
			return sPass;
		}

		public function set password(value:String):void {
			sPass = value;
		}

		public function get login():String {
			return sLogin;
		}

		public function set login(value:String):void {
			sLogin = value;
		}

		private var authenticated:Boolean, authenticating:Boolean;

		public function authenticate(pLogin:String = "", pPass:String = ""):void {
			if (authenticated || authenticating)
				return;
			if (pLogin == "" || pPass == "") {

			} else {
				sLogin = pLogin;
				sPass = pPass;
			}
			authenticating = true;
			authenticated = false;
			var c:Array = [ "EHLO " + sHost, "AUTH LOGIN", Base64.encode64String(sLogin), Base64.encode64String(sPass)];
			addToQueue(c);
			startQueue();
		}

		/*
		* This method is used to send emails with attached files and HTML
		* takes an incoming Bytearray and convert it to base64 string
		* for instance pass a JPEG ByteArray stream to get a picture attached in the mail ;)
		*/
		public function sendAttachedMail(pFrom:String, pDest:String, pSubject:String, pMess:String, pByteArray:ByteArray, pFileName:String, fromName:String = ""):void {
			try {
				authenticate(sLogin, sPass);
				var md5Boundary:String = MD5.hash(String(getTimer()));
				var base64String:String = Base64.encode64(pByteArray, true);
				var c:Array = [ "MAIL FROM: <" + pFrom + ">", "RCPT TO: <" + pDest + ">", "DATA\r\n" + "From: " + fromName + "<" + pFrom + ">\r\n" + "To: " + pDest + "\r\n" + "Date: " + new Date().toString() + "\r\n" + "Subject: " + pSubject + "\r\n" + "MIME-Version: 1.0\r\n" + "Content-Type: multipart/mixed; boundary=------------" + md5Boundary + "\r\n\r\n" + "This is a multi-part message in MIME format.\r\n" + "--------------" + md5Boundary + "\r\n" + "Content-Type: text/html; charset=UTF-8; format=flowed\r\n\r\n" + pMess + "\r\n" + "--------------" + md5Boundary + "\r\n" + readHeader(pByteArray, pFileName) + "Content-Transfer-Encoding: base64\r\n" + "\r\n" + base64String + "\r\n" + "--------------" + md5Boundary + "-\r\n" + "." ];
				addToQueue(c);
				startQueue();

			} catch (pError:Error) {
				trace("Error : Socket error, please check the sendAttachedMail() method parameters");
				trace("Arguments : " + arguments);
			}
		}

		/*
		* This method is used to send HTML emails
		* just pass the HTML string to pMess
		*/
		public function sendHTMLMail(pFrom:String, pDest:String, pSubject:String, pMess:String, fromName:String = ""):void {
			try {

				authenticate(sLogin, sPass);
				var c:Array = [ "MAIL FROM: <" + pFrom + ">", "RCPT TO: <" + pDest + ">", "DATA\r\n" + "From: " + fromName + "<" + pFrom + ">\r\n" + "To: " + pDest + "\r\n" + "Date: " + new Date().toString() + "\r\n" + "Subject: " + pSubject + "\r\n" + "MIME-Version: 1.0\r\n" + "Content-Type: text/html; charset=UTF-8; format=flowed\r\n\r\n" + pMess + "", "." ];
				addToQueue(c);
				startQueue();

			} catch (pError:Error) {
				trace("Error : Socket error, please check the sendHTMLMail() method parameters");
				trace("Arguments : " + arguments);
			}
		}

		public function sendPlainTextMail(from:String, to:String, subject:String, message:String, fromName:String = ""):void {
			try {

				authenticate(sLogin, sPass);
				var c:Array = [ "MAIL FROM: <" + from + ">", "RCPT TO: <" + to + ">", "DATA\r\n" + "From: " + fromName + "<" + from + ">\r\n" + "To: " + to + "\r\n" + "Subject: " + subject + "\r\n" + "MIME-Version: 1.0\r\n" + "Content-Type: text/plain; charset=UTF-8; format=flowed\r\n\r\n" + message + "", "." ];

				addToQueue(c);
				startQueue();

			} catch (pError:Error) {
				trace("Error : Socket error, please check the sendHTMLMail() method parameters");
				trace("Arguments : " + arguments);
			}
		}

		public function sendTestMail(from:String, to:String, fromName:String = ""):void {
			try {

				authenticate(sLogin, sPass);
				var c:Array = [ "MAIL FROM: <" + from + ">", "RCPT TO: <" + to + ">", "DATA\r\n" + "From: " + fromName + "<" + from + ">\r\n" + "To: " + to + "\r\n" + "Subject: Testing SMTPTLSMailer\r\n" + "MIME-Version: 1.0\r\n" + "Content-Type: text/html; charset=UTF-8; format=flowed\r\n\r\n" + "That you are seeing this email means it works :)", "." ];

				addToQueue(c);
				startQueue();
				trace("queued test email");

			} catch (pError:Error) {
				trace("Error : Socket error, please check the sendHTMLMail() method parameters");
				trace("Arguments : " + arguments);
			}
		}

		private var working:Boolean;

		private var queue:Array = [];

		private function addToQueue(commands:Array):void {
			queue = queue.concat(commands);
		}

		private function startQueue():void {
			if (working || !connected)
				return;
			working = true;
			removeEventListener(ProgressEvent.SOCKET_DATA, socketDataHandler);
			addEventListener(ProgressEvent.SOCKET_DATA, queueHandler);

			var command:String = queue.shift();
			writeUTFBytes(command + "\r\n");
			flush();
		}
		
		public function clearQueue():void {
			queue.length=0;
		}

		private function queueHandler(event:ProgressEvent):void {
			var response:String = event.target.readUTFBytes(event.target.bytesAvailable);

			if(response == "") {
				trace("Blank response, ignoring");
				return;
			}
			
			trace(response);

			buffer.length = 0;
			var result:Array = reg.exec(response);

			while (result != null) {
				buffer.push(result[0]);
				result = reg.exec(response);
			}

			var smtpReturn:Number = buffer[buffer.length - 1];
			var smtpInfos:SMTPInfos = new SMTPInfos(smtpReturn, response);

			if (ERROR_CODES.indexOf(smtpReturn) != -1) {
				dispatchEvent(new SMTPEvent(SMTPEvent.MAIL_ERROR, smtpInfos));
				working = false;
				removeEventListener(ProgressEvent.SOCKET_DATA, queueHandler);
				addEventListener(ProgressEvent.SOCKET_DATA, socketDataHandler);
				return;
			}

			if (queue.length == 0) {
				working = false;
				removeEventListener(ProgressEvent.SOCKET_DATA, queueHandler);
				addEventListener(ProgressEvent.SOCKET_DATA, socketDataHandler);
				evt(response, smtpReturn, smtpInfos);
				/*writeUTFBytes("QUIT\r\n");
				flush();*/
			} else {
				
				if (evt(response, smtpReturn, smtpInfos)) {
					var command:String = queue.shift();
					trace(command);
					dispatchEvent(ResultEvent.createEvent(command));
					writeUTFBytes(command + "\r\n");
					flush();
				}
			}
		}

		/*
		* This method automatically detects the header of the binary stream and returns appropriate headers (jpg, png)
		* classic application/octet-stream content type is added for different kind of files
		*/
		private function readHeader(pByteArray:ByteArray, pFileName:String):String {
			pByteArray.position = 0;

			var sOutput:String = null;

			if (pByteArray.readUnsignedInt() == SMTPTLSMailer.PNG) {
				sOutput = "Content-Type: image/png; name=" + pFileName + "\r\n";
				sOutput += "Content-Disposition: attachment filename=" + pFileName + "\r\n";
				return sOutput;
			}

			pByteArray.position = 0;

			if (pByteArray.readUnsignedShort() == SMTPTLSMailer.JPEG) {
				sOutput = "Content-Type: image/jpeg; name=" + pFileName + "\r\n";
				sOutput += "Content-Disposition: attachment filename=" + pFileName + "\r\n";
				return sOutput;
			}

			sOutput = "Content-Type: application/octet-stream; name=" + pFileName + "\r\n";
			sOutput += "Content-Disposition: attachment filename=" + pFileName + "\r\n";

			return sOutput;
		}

		// check SMTP response and dispatch proper events
		// Keep in mind SMTP servers can have different result messages the detection can be modified to match some specific SMTP servers
		private function socketDataHandler(pEvt:ProgressEvent):void {
			var response:String = pEvt.target.readUTFBytes(pEvt.target.bytesAvailable);
			
			if(response == "") {
				trace("Blank response, ignored");
				return;
			}
			trace(response);

			buffer.length = 0;
			var result:Array = reg.exec(response);

			while (result != null) {
				buffer.push(result[0]);
				result = reg.exec(response);
			}

			var smtpReturn:Number = buffer[buffer.length - 1];
			var smtpInfos:SMTPInfos = new SMTPInfos(smtpReturn, response);

			evt(response, smtpReturn, smtpInfos);
		}

		private var lastStatus:int;
		private function evt(response:String, smtpReturn:Number, smtpInfos:SMTPInfos):Boolean {
			var rv:Boolean = true;
			response=StringUtil.trim(response);
			if (smtpReturn == SMTPTLSMailer.READY)
				dispatchEvent(new SMTPEvent(SMTPEvent.CONNECTED, smtpInfos));

			else if (smtpReturn == SMTPTLSMailer.ACTION_OK && ((response.toLowerCase().indexOf("queued") != -1 || response.toLowerCase().indexOf("accepted") != -1 || response.toLowerCase().indexOf("qp") != -1 || response.toLowerCase().indexOf("id=") != -1 || response.toLowerCase().indexOf("2.0.0") != -1) && lastStatus == DATA))
				dispatchEvent(new SMTPEvent(SMTPEvent.MAIL_SENT, smtpInfos));
			else if (smtpReturn == SMTPTLSMailer.ACTION_OK /*&& response.toLowerCase().indexOf("\r\n") != -1*/) {
				//do nothing
			}
			else if (smtpReturn == SMTPTLSMailer.AUTHENTICATED) {
				dispatchEvent(new SMTPEvent(SMTPEvent.AUTHENTICATED, smtpInfos));
				authenticating = false;
				authenticated = true;
			} else if (smtpReturn == SMTPTLSMailer.DISCONNECTED)
				dispatchEvent(new SMTPEvent(SMTPEvent.DISCONNECTED, smtpInfos));
			else if (smtpReturn == SMTPTLSMailer.BAD_SEQUENCE) {
				dispatchEvent(new SMTPEvent(SMTPEvent.BAD_SEQUENCE, smtpInfos));
				rv = false;
			} else if (smtpReturn == SMTPTLSMailer.AUTH_DETAILS)
				sendAuth(response);
			else if (smtpReturn != SMTPTLSMailer.DATA)
				dispatchEvent(new SMTPEvent(SMTPEvent.MAIL_ERROR, smtpInfos));

			lastStatus=smtpReturn;
			dispatchEvent(ResultEvent.createEvent(response));
			return rv;
		}

		private var authprogress:int = 0;

		private function sendAuth(response:String):void {
			/*if (authprogress == 0) {
				writeUTFBytes(Base64.encode64String(sLogin) + "\r\n");
				flush();
			} else if (authprogress == 1) {
				writeUTFBytes(Base64.encode64String(sPass) + "\r\n");
				flush();
			}*/

			authprogress++;
		}

		public function quit():void {
			addToQueue([ "QUIT" ]);
			startQueue();
		}



		private function errorHandler(e:IOErrorEvent):void {
			trace("IOError: " + e.toString());
		}
	}
}
