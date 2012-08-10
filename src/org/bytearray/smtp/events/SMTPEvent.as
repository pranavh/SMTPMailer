package org.bytearray.smtp.events

{
	
	import flash.events.Event;
	
	public class SMTPEvent extends Event 
	
	{
		
		public static const MAIL_SENT:String = "mailSent";
		public static const AUTHENTICATED:String = "authenticated";
		public static const MAIL_ERROR:String = "mailError";
		public static const BAD_SEQUENCE:String = "badSequence";
		public static const CONNECTED:String = "connected";
		public static const DISCONNECTED:String = "disconnected";
		public static const ERROR:String = "error";
		
		public var result:Object;
		
		public function SMTPEvent ( pEvent:String, pInfos:Object )
		
		{
			
			super ( pEvent );
			
			result = pInfos;
			
		}
		
	}
	
}