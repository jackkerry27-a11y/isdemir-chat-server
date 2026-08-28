import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  bool _isLoading = true;
  String _error = '';
  List<Map<String, dynamic>> _teamMembers = [];

  @override
  void initState() {
    super.initState();
    _fetchTeamData();
  }

  Future<void> _fetchTeamData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await Supabase.instance.client.from('personel').select('''
        id, ad_soyad, meslek, durum,
        giris_cikis_log(tarih, islem_tipi, saat)
      ''').eq('durum', 'onaylandi');

      final List<Map<String, dynamic>> processedList = [];

      for (var p in response as List<dynamic>) {
        final logs = List<Map<String, dynamic>>.from(p['giris_cikis_log'] ?? []);
        
        // Sort logs by date and time descending to get the latest action
        logs.sort((a, b) {
          final dateA = DateTime.parse('${a['tarih']}T${a['saat']}');
          final dateB = DateTime.parse('${b['tarih']}T${b['saat']}');
          return dateB.compareTo(dateA);
        });

        String status = 'pasif'; // Default status
        String lastActionTime = 'Hiç hareket yok';

        if (logs.isNotEmpty) {
          final lastLog = logs.first;
          final isGiris = lastLog['islem_tipi'] == 'is_giris';
          
          status = isGiris ? 'aktif' : 'pasif';
          lastActionTime = '${lastLog['tarih'].toString().split('T').first} ${lastLog['saat']}';
        }

        processedList.add({
          'id': p['id'],
          'ad_soyad': p['ad_soyad'],
          'meslek': p['meslek'] ?? 'Belirtilmedi',
          'aktif_durum': status,
          'son_hareket': lastActionTime,
        });
      }

      setState(() {
        _teamMembers = processedList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _getInitials(String name) {
    List<String> names = name.trim().split(' ');
    String initials = '';
    int numWords = names.length > 2 ? 2 : names.length;
    for (int i = 0; i < numWords; i++) {
      if (names[i].isNotEmpty) {
        initials += names[i][0].toUpperCase();
      }
    }
    return initials;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Ekip', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF4338CA),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF4338CA),
        onRefresh: _fetchTeamData,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4338CA)))
          : _error.isNotEmpty
            ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
            : _teamMembers.isEmpty
              ? const Center(child: Text('Kayıtlı aktif personel bulunamadı.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _teamMembers.length,
                  itemBuilder: (context, index) {
                    final member = _teamMembers[index];
                    final isAktif = member['aktif_durum'] == 'aktif';

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: isAktif ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.grey.shade100,
                                  child: Text(
                                    _getInitials(member['ad_soyad'] ?? ''),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isAktif ? const Color(0xFF10B981) : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0, bottom: 0,
                                  child: Container(
                                    width: 14, height: 14,
                                    decoration: BoxDecoration(
                                      color: isAktif ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member['ad_soyad'] ?? '',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A202C)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    member['meslek'] ?? '',
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF4A5568)),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isAktif ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isAktif ? 'Fabrikada' : 'Dışarıda',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isAktif ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  member['son_hareket'],
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFA0AEC0)),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
