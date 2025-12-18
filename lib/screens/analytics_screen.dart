import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../services/database_service.dart';
import '../models/app_settings.dart';
import '../utils/theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final DatabaseService _dbService = DatabaseService();
  
  int _totalMessages = 0;
  int _totalPromptTokens = 0;
  int _totalCompletionTokens = 0;
  int _freeMessagesToday = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
    _fetchKeyInfo();
  }

  Future<void> _fetchKeyInfo() async {
    final settingsProvider = context.read<SettingsProvider>();
    await settingsProvider.fetchOpenRouterKeyInfo();
  }

  Future<void> _loadAnalytics() async {
    final settingsProvider = context.read<SettingsProvider>();
    final data = await _dbService.getAnalyticsData();
    
    int freeCount = 0;
    final keyInfo = settingsProvider.openRouterKeyInfo;
    if (keyInfo != null && keyInfo['label'] != null) {
      freeCount = await _dbService.getFreeMessagesTodayCount(keyInfo['label']);
    }

    if (mounted) {
      setState(() {
        _totalMessages = data['totalMessages'] ?? 0;
        _totalPromptTokens = data['promptTokens'] ?? 0;
        _totalCompletionTokens = data['completionTokens'] ?? 0;
        _freeMessagesToday = freeCount;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final chatCount = chatProvider.chats.length;
    
    // Current chat stats (from memory - this works)
    final currentChat = chatProvider.currentChat;
    final currentChatTokens = chatProvider.totalTokensInCurrentChat;
    final currentChatMessages = currentChat?.messages.length ?? 0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadAnalytics();
              _fetchKeyInfo();
            },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // OpenRouter Quota section (if applicable)
                if (settingsProvider.settings.apiProvider == ApiProvider.openRouter && 
                    settingsProvider.openRouterKeyInfo != null) ...[
                  _buildSectionTitle(context, 'OpenRouter Daily Quota'),
                  const SizedBox(height: 12),
                  _buildQuotaCard(context, settingsProvider.openRouterKeyInfo!),
                  const SizedBox(height: 24),
                ],

                // Current Session Card
                _buildSectionTitle(context, 'Current Session'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.token,
                        label: 'Tokens',
                        value: _formatNumber(currentChatTokens),
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.chat_bubble_outline,
                        label: 'Messages',
                        value: currentChatMessages.toString(),
                        color: AppTheme.accent,
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.1),
                
                const SizedBox(height: 24),
                
                // All Time Stats
                _buildSectionTitle(context, 'All Time'),
                const SizedBox(height: 12),
                _buildTokenBreakdownCard(
                  context,
                  promptTokens: _totalPromptTokens,
                  completionTokens: _totalCompletionTokens,
                ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideX(begin: -0.1),
                
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.forum_outlined,
                        label: 'Chats',
                        value: chatCount.toString(),
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.message_outlined,
                        label: 'Messages',
                        value: _formatNumber(_totalMessages),
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 300.ms, delay: 200.ms).slideX(begin: -0.1),
                
                const SizedBox(height: 24),
                
                // Tips Card
                _buildTipsCard(context).animate().fadeIn(duration: 300.ms, delay: 300.ms).slideY(begin: 0.1),
              ],
            ),
          ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenBreakdownCard(
    BuildContext context, {
    required int promptTokens,
    required int completionTokens,
  }) {
    final total = promptTokens + completionTokens;
    final promptPercent = total > 0 ? promptTokens / total : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Tokens',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Text(
                _formatNumber(total),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: promptPercent,
              backgroundColor: AppTheme.accent.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTokenLabel(context, 'Prompt', promptTokens, Theme.of(context).colorScheme.primary),
              _buildTokenLabel(context, 'Completion', completionTokens, AppTheme.accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTokenLabel(BuildContext context, String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ${_formatNumber(count)}',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildTipsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            AppTheme.accent.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lightbulb_outline, color: Colors.amber),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pro Tip',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Token tracking requires API support. LM Studio may need specific model settings to return usage data.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaCard(BuildContext context, Map<String, dynamic> keyInfo) {
    final usageDaily = (keyInfo['usage_daily'] as num?)?.toDouble() ?? 0.0;
    // OpenRouter daily limit for free tier is typically 50 requests if credits < 10, or 1000 if >= 10.
    // However, the 'limit' field is in USD/credits. Usage_daily is also in credits.
    // For free models, they cost 0 credits.
    // The 50 message limit is a rate limit/quota, not strictly a credit limit.
    // But we can show the daily usage (credits) and the tier info.
    
    final isFreeTier = keyInfo['is_free_tier'] == true;
    final label = keyInfo['label'] ?? 'API Key';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isFreeTier ? 'Free Tier' : 'Paid Tier',
                      style: TextStyle(
                        fontSize: 12,
                        color: isFreeTier ? Colors.green : Colors.amber,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.vignette_outlined, color: Colors.blue),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQuotaStat('Used Today (Credits)', '\$${usageDaily.toStringAsFixed(4)}'),
              if (keyInfo['limit'] != null)
                _buildQuotaStat('Daily Limit', '\$${(keyInfo['limit'] as num).toStringAsFixed(2)}'),
            ],
          ),
          if (isFreeTier) ...[
             const SizedBox(height: 16),
             _buildQuotaStat('Free Messages Today (approx)', '$_freeMessagesToday / 50'),
             const SizedBox(height: 12),
             const Divider(color: Colors.white10),
             const SizedBox(height: 8),
             const Row(
               children: [
                 Icon(Icons.info_outline, size: 14, color: Colors.blue),
                 SizedBox(width: 8),
                 Expanded(
                   child: Text(
                     'Free models are limited to 50 requests per day on the Free Tier.',
                     style: TextStyle(fontSize: 11, color: Colors.white70),
                   ),
                 ),
               ],
             ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuotaStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white60),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
