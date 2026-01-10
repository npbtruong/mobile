import 'dart:io';

class ConnectivityService {
	const ConnectivityService();

	Future<bool> hasInternetConnection() async {
		try {
			final result = await InternetAddress.lookup('example.com');
			return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
		} catch (_) {
			return false;
		}
	}
}

