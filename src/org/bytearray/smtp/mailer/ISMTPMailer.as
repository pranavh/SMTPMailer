package org.bytearray.smtp.mailer
{
	import flash.utils.ByteArray;

	public interface ISMTPMailer
	{
				
		function get login():String;
		function get password():String;
		function set login(value:String):void;
		function set password(value:String):void;
		
		function authenticate(login:String="", password:String=""):void;
		
		function sendHTMLMail(pFrom:String, pDest:String, pSubject:String, pMess:String, fromName:String=""):void;
		function sendAttachedMail(pFrom:String, pDest:String, pSubject:String, pMess:String, pByteArray:ByteArray, pFileName:String, fromName:String=""):void;
		function sendPlainTextMail(from:String, to:String, subject:String, message:String, fromName:String=""):void;
		function sendTestMail(from:String, to:String, fromName:String=""):void;
	}
}