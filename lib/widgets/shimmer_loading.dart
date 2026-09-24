import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Lüks Karanlık Tema Shimmer Konteyneri
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Shimmer.fromColors(
        baseColor: const Color(0xFF1E232A),
        highlightColor: const Color(0xFF333D48),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF1E232A),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}

/// Gemi Kartları İskelet Yükleyicisi (Gemiler Ekranı için)
class ShipListSkeleton extends StatelessWidget {
  const ShipListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Üst İstatistik Barı İskeleti
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          color: const Color(0xFF1C1C22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              4,
              (index) => Column(
                children: [
                  const ShimmerBox(width: 24, height: 24, borderRadius: 12),
                  const SizedBox(height: 8),
                  const ShimmerBox(width: 32, height: 18, borderRadius: 4),
                  const SizedBox(height: 6),
                  const ShimmerBox(width: 48, height: 10, borderRadius: 4),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Gemi Kartları
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 4,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Rıhtım Rozet İskeleti
                        const ShimmerBox(width: 80, height: 32, borderRadius: 8),
                        const Spacer(),
                        // Durum İskeleti
                        const ShimmerBox(width: 110, height: 26, borderRadius: 12),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Gemi Adı İskeleti
                    const ShimmerBox(width: 180, height: 20, borderRadius: 6),
                    const SizedBox(height: 12),
                    // Yük cinsi ve detaylar
                    Row(
                      children: [
                        const ShimmerBox(width: 90, height: 14, borderRadius: 4),
                        const SizedBox(width: 16),
                        const ShimmerBox(width: 120, height: 14, borderRadius: 4),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Posta Listesi Kart İskeleti (Posta Listeleri Ekranı için)
class PostaListSkeleton extends StatelessWidget {
  const PostaListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C22),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst Tarih ve Buton Barı
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const ShimmerBox(width: 36, height: 36, borderRadius: 18),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ShimmerBox(width: 140, height: 16, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerBox(width: 90, height: 12, borderRadius: 4),
                      ],
                    ),
                    const Spacer(),
                    const ShimmerBox(width: 36, height: 36, borderRadius: 18),
                  ],
                ),
              ),
              // Fotoğraf Önizleme Alanı
              const ShimmerBox(
                width: double.infinity,
                height: 220,
                borderRadius: 0,
              ),
              // Alt Bilgi Barı
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: const [
                    ShimmerBox(width: 120, height: 14, borderRadius: 4),
                    Spacer(),
                    ShimmerBox(width: 80, height: 14, borderRadius: 4),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Yemekhane Menüsü İskelet Yükleyicisi
class YemekMenuSkeleton extends StatelessWidget {
  const YemekMenuSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const ShimmerBox(width: 50, height: 50, borderRadius: 12),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBox(width: 160, height: 18, borderRadius: 4),
                    SizedBox(height: 8),
                    ShimmerBox(width: 100, height: 12, borderRadius: 4),
                  ],
                ),
              ),
              const ShimmerBox(width: 60, height: 24, borderRadius: 8),
            ],
          ),
        );
      },
    );
  }
}
