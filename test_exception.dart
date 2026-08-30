void main() async {
  await _routeToNextScreen();
  print("Navigation executed!");
}

Future<void> _routeToNextScreen() async {
  try {
    await _checkForceUpdate();
  } catch (e) {
    if (e.toString().contains('Force Update Required')) {
      print("Caught and returning");
      return;
    }
  }
  print("Pushing replacement!");
}

Future<void> _checkForceUpdate() async {
  try {
    print("Showing dialog");
    throw Exception('Force Update Required');
  } catch (e) {
    if (e.toString().contains('Force Update Required')) rethrow;
    print('Failed: $e');
  }
}
