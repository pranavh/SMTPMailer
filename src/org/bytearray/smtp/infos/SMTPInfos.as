package org.bytearray.smtp.infos
{
	public class SMTPInfos
	{
		public var code:int;
		public var message:String;
		
		public function SMTPInfos(code:int, message:String)
		{
			this.code = code;
			this.message = message;
		}
	}
}