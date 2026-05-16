/// All translation key constants — use with easy_localization's .tr() extension.
/// Example: AppStrings.appName.tr()
class AppStrings {
  AppStrings._();

  // App
  static const String appName = 'app_name';
  static const String appTagline = 'app_tagline';

  // Auth
  static const String login = 'auth.login';
  static const String register = 'auth.register';
  static const String email = 'auth.email';
  static const String password = 'auth.password';
  static const String name = 'auth.name';
  static const String age = 'auth.age';
  static const String forgotPassword = 'auth.forgot_password';
  static const String signInWithGoogle = 'auth.sign_in_google';
  static const String noAccount = 'auth.no_account';
  static const String alreadyAccount = 'auth.already_account';
  static const String acceptTerms = 'auth.accept_terms';
  static const String signOut = 'auth.sign_out';

  // Onboarding
  static const String onboardingTitle1 = 'onboarding.title1';
  static const String onboardingTitle2 = 'onboarding.title2';
  static const String onboardingTitle3 = 'onboarding.title3';
  static const String onboardingTitle4 = 'onboarding.title4';
  static const String onboardingTitle5 = 'onboarding.title5';
  static const String onboardingDesc1 = 'onboarding.desc1';
  static const String onboardingDesc2 = 'onboarding.desc2';
  static const String onboardingDesc3 = 'onboarding.desc3';
  static const String onboardingDesc4 = 'onboarding.desc4';
  static const String onboardingDesc5 = 'onboarding.desc5';
  static const String selectLanguage = 'onboarding.select_language';
  static const String selectFaith = 'onboarding.select_faith';
  static const String setGoals = 'onboarding.set_goals';
  static const String grantPermissions = 'onboarding.grant_permissions';
  static const String getStarted = 'onboarding.get_started';
  static const String next = 'common.next';
  static const String skip = 'common.skip';

  // Home
  static const String todayStress = 'home.today_stress';
  static const String quickScan = 'home.quick_scan';
  static const String morningCheckin = 'home.morning_checkin';
  static const String eveningCheckin = 'home.evening_checkin';
  static const String dailyTip = 'home.daily_tip';
  static const String currentStreak = 'home.current_streak';
  static const String days = 'home.days';
  static const String goodMorning = 'home.good_morning';
  static const String goodEvening = 'home.good_evening';

  // Navigation
  static const String navHome = 'nav.home';
  static const String navAnalytics = 'nav.analytics';
  static const String navMindfulness = 'nav.mindfulness';
  static const String navFamily = 'nav.family';
  static const String navProfile = 'nav.profile';

  // Stress
  static const String stressScore = 'stress.score';
  static const String stressLow = 'stress.low';
  static const String stressMedium = 'stress.medium';
  static const String stressHigh = 'stress.high';
  static const String stressCritical = 'stress.critical';
  static const String stressResult = 'stress.result';
  static const String stressTriggers = 'stress.triggers';
  static const String cameraScan = 'stress.camera_scan';
  static const String voiceCheckin = 'stress.voice_checkin';
  static const String scanInstruction = 'stress.scan_instruction';
  static const String voiceInstruction = 'stress.voice_instruction';
  static const String analyzing = 'stress.analyzing';
  static const String scanComplete = 'stress.scan_complete';

  // Check-in
  static const String sleepQuality = 'checkin.sleep_quality';
  static const String anxietyLevel = 'checkin.anxiety_level';
  static const String energyLevel = 'checkin.energy_level';
  static const String mentalClarity = 'checkin.mental_clarity';
  static const String overallMood = 'checkin.overall_mood';
  static const String workStress = 'checkin.work_stress';
  static const String gratitudeNote = 'checkin.gratitude_note';
  static const String checkinComplete = 'checkin.complete';

  // Mindfulness
  static const String mindfulness = 'mindfulness.title';
  static const String breathing = 'mindfulness.breathing';
  static const String meditation = 'mindfulness.meditation';
  static const String prayer = 'mindfulness.prayer';
  static const String journal = 'mindfulness.journal';
  static const String inhale = 'mindfulness.inhale';
  static const String hold = 'mindfulness.hold';
  static const String exhale = 'mindfulness.exhale';
  static const String startSession = 'mindfulness.start';
  static const String endSession = 'mindfulness.end';
  static const String minutes = 'mindfulness.minutes';
  static const String premiumContent = 'mindfulness.premium';

  // Analytics
  static const String analytics = 'analytics.title';
  static const String weeklyReport = 'analytics.weekly';
  static const String monthlyReport = 'analytics.monthly';
  static const String bestDay = 'analytics.best_day';
  static const String worstDay = 'analytics.worst_day';
  static const String avgStress = 'analytics.avg_stress';
  static const String topTriggers = 'analytics.top_triggers';
  static const String sleepGraph = 'analytics.sleep_graph';
  static const String moodCalendar = 'analytics.mood_calendar';

  // Family
  static const String family = 'family.title';
  static const String inviteMember = 'family.invite';
  static const String removeMember = 'family.remove';
  static const String alertPreferences = 'family.alert_prefs';
  static const String shareProgress = 'family.share_progress';
  static const String alertHighStress = 'family.alert_high_stress';
  static const String alertMissedCheckin = 'family.alert_missed_checkin';

  // Therapist
  static const String therapists = 'therapist.title';
  static const String bookSession = 'therapist.book';
  static const String availableSlots = 'therapist.slots';
  static const String onlineNow = 'therapist.online';
  static const String perSession = 'therapist.per_session';
  static const String filterBy = 'therapist.filter';

  // Profile
  static const String profile = 'profile.title';
  static const String editProfile = 'profile.edit';
  static const String subscription = 'profile.subscription';
  static const String notifications = 'profile.notifications';
  static const String privacy = 'profile.privacy';
  static const String freeTier = 'profile.free';
  static const String basicTier = 'profile.basic';
  static const String premiumTier = 'profile.premium';

  // Faith preferences
  static const String faithIslam = 'faith.islam';
  static const String faithChristian = 'faith.christian';
  static const String faithHindu = 'faith.hindu';
  static const String faithBuddhism = 'faith.buddhism';
  static const String faithSecular = 'faith.secular';

  // Common
  static const String save = 'common.save';
  static const String cancel = 'common.cancel';
  static const String confirm = 'common.confirm';
  static const String delete = 'common.delete';
  static const String edit = 'common.edit';
  static const String close = 'common.close';
  static const String loading = 'common.loading';
  static const String error = 'common.error';
  static const String noData = 'common.no_data';
  static const String retry = 'common.retry';
  static const String success = 'common.success';
  static const String submit = 'common.submit';
  static const String today = 'common.today';
  static const String week = 'common.week';
  static const String month = 'common.month';
  static const String shareWithFamily = 'common.share_with_family';
  static const String permissionDenied = 'common.permission_denied';
  static const String noInternet = 'common.no_internet';
}