embeddedServiceSnippet
	function initEmbeddedMessaging() {
		try {
			embeddedservice_bootstrap.settings.language = 'en_US'; // For example, enter 'en' or 'en-US'

			embeddedservice_bootstrap.init(
				'00Dbm00000flqht',
				'Electra_Pulse',
				'https://orgfarm-bae200b490.my.site.com/ESWElectraPulse1776538990875',
				{
					scrt2URL: 'https://orgfarm-bae200b490.my.salesforce-scrt.com'
				}
			);
		} catch (err) {
			console.error('Error loading Embedded Messaging: ', err);
		}
	};

