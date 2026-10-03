// =============================================================================
// App Icons — Centralized icon mapping for third-party icon packages
// =============================================================================
//
// This file isolates icon selections that come from external icon packages.
// Keeping a small app-level mapping lets us swap icon packages safely without
// touching many feature files.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// FORK: every glyph is Material Symbols Rounded at weight 400 (package default);
// semantic roles live in lib/fork/design/birdy_icons.dart (BirdyIcons).
abstract final class AppIcons {
  // Material icon mappings used across the project.
  static const IconData acUnit = Symbols.ac_unit_rounded;
  static const IconData add = Symbols.add_rounded;
  static const IconData addCircleOutline = Symbols.add_circle_rounded;
  static const IconData addRounded = Symbols.add_rounded;
  static const IconData air = Symbols.air_rounded;
  static const IconData airRounded = Symbols.air_rounded;
  static const IconData airplaneTicket = Symbols.airplane_ticket_rounded;
  static const IconData arrowBackRounded = Symbols.arrow_back_rounded;
  static const IconData arrowDownward = Symbols.arrow_downward_rounded;
  static const IconData arrowForwardRounded =
      Symbols.arrow_forward_rounded; // FORK: quiz « Continuer » (J6e)
  static const IconData arrowDropUpRounded = Symbols.arrow_drop_up_rounded;
  // Keep style-explicit names when outlined and rounded variants are both used.
  static const IconData audioFileOutlined = Symbols.audio_file_rounded;
  static const IconData audioFileRounded = Symbols.audio_file_rounded;
  static const IconData barChart = Symbols.bar_chart_rounded;
  static const IconData batteryAlert = Symbols.battery_alert_rounded;
  static const IconData batteryChargingFull = Symbols.battery_charging_full_rounded;
  static const IconData batterySaverRounded = Symbols.battery_saver_rounded;
  static const IconData bluetoothAudio = Symbols.bluetooth_audio_rounded;
  static const IconData bookmarkAdded = Symbols.bookmark_added_rounded;
  static const IconData bird = Symbols.raven_rounded; // FORK: species silhouette (J6a)
  static const IconData brokenImage = Symbols.broken_image_rounded;
  static const IconData calendarToday = Symbols.calendar_today_rounded;
  static const IconData calendarTodayRounded = Symbols.calendar_today_rounded;
  static const IconData campaign = Symbols.campaign_rounded;
  static const IconData category = Symbols.category_rounded;
  static const IconData check = Symbols.check_rounded;
  static const IconData checkCircle = Symbols.check_circle_rounded;
  static const IconData checkCircleOutline = Symbols.check_circle_rounded;
  static const IconData checkCircleRounded = Symbols.check_circle_rounded;
  static const IconData checkRounded = Symbols.check_rounded;
  static const IconData chevronLeft =
      Symbols.chevron_left_rounded; // FORK: quick review swipe hints (J6c)
  static const IconData chevronRight = Symbols.chevron_right_rounded;
  static const IconData chevronUp =
      Symbols.keyboard_arrow_up_rounded; // FORK: quick review swipe hints (J6c)
  static const IconData clear = Symbols.clear_rounded;
  static const IconData clearRounded = Symbols.clear_rounded;
  static const IconData close = Symbols.close_rounded;
  static const IconData closeRounded = Symbols.close_rounded;
  static const IconData cloudOff = Symbols.cloud_off_rounded;
  static const IconData cloud = Symbols.cloud_rounded;
  static const IconData cloudy = Symbols.cloudy_rounded;
  static const IconData code = Symbols.code_rounded;
  static const IconData contentCut = Symbols.content_cut_rounded;
  static const IconData darkMode = Symbols.dark_mode_rounded;
  static const IconData deleteOutline = Symbols.delete_rounded;
  static const IconData deleteOutlineRounded = Symbols.delete_outline_rounded;
  static const IconData deleteSweep = Symbols.delete_sweep_rounded;
  static const IconData diamond = Symbols.diamond_rounded; // FORK: rarity mark (J6a)
  static const IconData directionsWalkRounded = Symbols.directions_walk_rounded;
  static const IconData detections = Symbols.list_alt_rounded;
  static const IconData downloadForOffline = Symbols.download_for_offline_rounded;
  static const IconData edit = Symbols.edit_rounded;
  static const IconData editLocationAlt = Symbols.edit_location_alt_rounded;
  static const IconData editNote = Symbols.edit_note_rounded;
  static const IconData errorOutline = Symbols.error_outline_rounded;
  static const IconData errorOutlineRounded = Symbols.error_outline_rounded;
  static const IconData expandLess = Symbols.expand_less_rounded;
  static const IconData expandMore = Symbols.expand_more_rounded;
  static const IconData fiberManualRecord = Symbols.fiber_manual_record_rounded;
  static const IconData fiberManualRecordRounded =
      Symbols.fiber_manual_record_rounded;
  static const IconData filterAltRounded = Symbols.filter_alt_rounded;
  static const IconData filterList = Symbols.filter_list_rounded;
  static const IconData flagFilled = Symbols.flag_rounded; // FORK: unify on Material Symbols (callers use fill: 1)
  static const IconData flagRounded = Symbols.flag_rounded;
  static const IconData foggy = Symbols.foggy_rounded;
  static const IconData formatListNumberedRounded =
      Symbols.format_list_numbered_rounded;
  static const IconData fullscreen = Symbols.fullscreen_rounded;
  static const IconData gavel = Symbols.gavel_rounded;
  static const IconData gavelRounded = Symbols.gavel_rounded;
  static const IconData grain = Symbols.grain_rounded;
  static const IconData graphicEq = Symbols.graphic_eq_rounded;
  static const IconData graphicEqRounded = Symbols.graphic_eq_rounded;
  static const IconData gridViewRounded = Symbols.grid_view_rounded;
  static const IconData hearing = Symbols.hearing_rounded;
  static const IconData headphones =
      Symbols.headphones_rounded; // FORK: « Oreille fine » badge (J6e)
  static const IconData helpOutline = Symbols.help_rounded;
  static const IconData helpOutlineRounded = Symbols.help_outline_rounded;
  static const IconData hourglassTopRounded = Symbols.hourglass_top_rounded;
  static const IconData home = Symbols.home_rounded; // FORK: bottom navigation (J6e)
  static const IconData imageNotSupported = Symbols.image_not_supported_rounded;
  static const IconData infoOutline = Symbols.info_rounded;
  static const IconData landscapeRounded = Symbols.landscape_rounded;
  static const IconData libraryBooks = Symbols.library_books_rounded;
  static const IconData libraryMusic = Symbols.library_music_rounded;
  static const IconData lightbulbOutline = Symbols.lightbulb_rounded;
  static const IconData listAlt = Symbols.list_alt_rounded;
  static const IconData listAltRounded = Symbols.list_alt_rounded;
  static const IconData locationOff = Symbols.location_off_rounded;
  static const IconData locationOffRounded = Symbols.location_off_rounded;
  static const IconData locationOn = Symbols.location_on_rounded;
  static const IconData locationOnRounded = Symbols.location_on_rounded;
  static const IconData layers = Symbols.layers_rounded; // FORK: map base layers (J5)
  static const IconData leaderboard = Symbols.leaderboard_rounded; // FORK: Palmarès (J6e)
  static const IconData lockOutline = Symbols.lock_rounded;
  static const IconData map = Symbols.location_on_rounded;
  static const IconData mapSheet = Symbols.map_rounded;
  static const IconData memory = Symbols.memory_rounded;
  static const IconData menu = Symbols.menu_rounded; // FORK: home menu (J6c)
  static const IconData menuBook = Symbols.menu_book_rounded;
  static const IconData mic = Symbols.mic_rounded;
  static const IconData micExternalOnRounded = Symbols.mic_external_on_rounded;
  static const IconData micNone = Symbols.mic_none_rounded;
  // Kept for style clarity alongside mic/micRounded/micOff variants.
  static const IconData micNoneOutlined = Symbols.mic_none_rounded;
  static const IconData micOff = Symbols.mic_off_rounded;
  static const IconData micRounded = Symbols.mic_rounded;
  static const IconData moreHoriz = Symbols.more_horiz_rounded; // FORK: J6h
  static const IconData moreVert = Symbols.more_vert_rounded;
  static const IconData wbTwilight = Symbols.wb_twilight_rounded; // FORK: J6h
  static const IconData smartphone = Symbols.smartphone_rounded; // FORK: J6h
  static const IconData translate = Symbols.translate_rounded; // FORK: J6h
  static const IconData image = Symbols.image_rounded; // FORK: J6h
  static const IconData visibilityOff = Symbols.visibility_off_rounded; // FORK: J6h
  static const IconData flight = Symbols.flight_rounded; // FORK: J6h
  static const IconData notifications = Symbols.notifications_rounded; // FORK: J6h
  static const IconData autoAwesome = Symbols.auto_awesome_rounded; // FORK: J6h
  static const IconData musicNote = Symbols.music_note_rounded;
  static const IconData myLocation = Symbols.my_location_rounded;
  static const IconData noteAdd = Symbols.note_add_rounded;
  // Kept as explicit style variant for notification status icon usage.
  static const IconData notificationsActiveOutlined =
      Symbols.notifications_active_rounded;
  static const IconData notificationsActiveRounded =
      Symbols.notifications_active_rounded;
  static const IconData openInNew = Symbols.open_in_new_rounded;
  static const IconData parkRounded = Symbols.park_rounded;
  static const IconData pause = Symbols.pause_rounded;
  static const IconData pauseRounded = Symbols.pause_rounded;
  static const IconData partlyCloudyDay = Symbols.partly_cloudy_day_rounded;
  static const IconData percent = Symbols.percent_rounded;
  static const IconData personOutline = Symbols.person_rounded;
  static const IconData personPinCircleRounded =
      Symbols.person_pin_circle_rounded;
  static const IconData personRounded = Symbols.person_rounded;
  static const IconData playArrow = Symbols.play_arrow_rounded;
  static const IconData playArrowRounded = Symbols.play_arrow_rounded;
  static const IconData playCircleOutline = Symbols.play_circle_rounded;
  static const IconData privacyTip = Symbols.privacy_tip_rounded;
  static const IconData public = Symbols.public_rounded;
  static const IconData publicOffRounded = Symbols.public_off_rounded;
  static const IconData question = Symbols.question_mark_rounded; // FORK: home (J6c)
  static const IconData radioButtonUnchecked = Symbols.radio_button_unchecked_rounded;
  static const IconData redo = Symbols.redo_rounded;
  static const IconData refresh = Symbols.refresh_rounded;
  static const IconData restartAlt = Symbols.restart_alt_rounded;
  static const IconData repeatRounded = Symbols.repeat_rounded;
  static const IconData reportProblem = Symbols.report_problem_rounded;
  static const IconData rainy = Symbols.rainy_rounded;
  static const IconData rainyLight = Symbols.rainy_light_rounded;
  // Kept as outlined to pair with routeRounded where style is intentional.
  static const IconData routeOutlined = Symbols.route_rounded;
  static const IconData routeRounded = Symbols.route_rounded;
  static const IconData save = Symbols.save_rounded;
  static const IconData saveAlt = Symbols.save_alt_rounded;
  static const IconData saveRounded = Symbols.save_rounded;
  static const IconData schedule = Symbols.schedule_rounded;
  static const IconData scheduleRounded = Symbols.schedule_rounded;
  // Kept as outlined to pair with scienceRounded.
  static const IconData scienceOutlined = Symbols.science_rounded;
  static const IconData scienceRounded = Symbols.science_rounded;
  static const IconData sdStorage = Symbols.sd_storage_rounded;
  static const IconData search = Symbols.search_rounded;
  static const IconData searchOff = Symbols.search_off_rounded;
  static const IconData searchRounded = Symbols.search_rounded;
  static const IconData securityRounded = Symbols.security_rounded;
  static const IconData send = Symbols.send_rounded;
  static const IconData selectAll = Symbols.select_all_rounded;
  static const IconData deselect = Symbols.deselect_rounded;
  static const IconData share = Symbols.share_rounded;
  static const IconData shortText = Symbols.short_text_rounded;
  static const IconData skipNextRounded = Symbols.skip_next_rounded;
  static const IconData skipPreviousRounded = Symbols.skip_previous_rounded;
  static const IconData sort = Symbols.sort_rounded;
  static const IconData sparkle = Symbols.auto_awesome_rounded; // FORK: novelty pills (J6a)
  static const IconData species = Symbols.graphic_eq_rounded;
  static const IconData speciesFallback = brokenImage;
  static const IconData speedRounded = Symbols.speed_rounded;
  static const IconData stickyNote2 = Symbols.sticky_note_2_rounded;
  static const IconData stop = Symbols.stop_rounded; // FORK: unify on Material Symbols (callers use fill: 1)
  static const IconData star = Symbols.star_rounded; // FORK: sound library favorites
  static const IconData contentCopy =
      Symbols.content_copy_rounded; // FORK: LPO card (J5b)
  static const IconData remove = Symbols.remove_rounded; // FORK: counters (J5b)
  static const IconData stopRounded = Symbols.stop_rounded; // FORK: unify on Material Symbols (callers use fill: 1)
  static const IconData storage = Symbols.storage_rounded;
  static const IconData straighten = Symbols.straighten_rounded;
  static const IconData summaryChart = Symbols.bar_chart_rounded;
  static const IconData swapHoriz = Symbols.swap_horiz_rounded;
  static const IconData thunderstorm = Symbols.thunderstorm_rounded;
  static const IconData timerOff = Symbols.timer_off_rounded;
  // Kept as outlined to pair with timerRounded.
  static const IconData timerOutlined = Symbols.timer_rounded;
  static const IconData timerRounded = Symbols.timer_rounded;
  static const IconData touchApp = Symbols.touch_app_rounded;
  static const IconData travelExplore = Symbols.travel_explore_rounded;
  static const IconData tune = Symbols.tune_rounded;
  static const IconData tuneRounded = Symbols.tune_rounded;
  static const IconData undo = Symbols.undo_rounded;
  static const IconData uploadFileRounded = Symbols.upload_file_rounded;
  static const IconData verifiedRounded = Symbols.verified_rounded;
  static const IconData vibrationRounded = Symbols.vibration_rounded;

  /// Visual observation ("seen"). Pairs with [hearing] on manual detections.
  static const IconData visibility = Symbols.visibility_rounded;
  static const IconData volunteerActivism = Symbols.volunteer_activism_rounded;
  static const IconData volumeDown = Symbols.volume_down_rounded;
  static const IconData volumeMuteRounded = Symbols.volume_mute_rounded;
  static const IconData volumeOffRounded = Symbols.volume_off_rounded;
  // Kept as outlined to pair with volumeUpRounded.
  static const IconData volumeUpOutlined = Symbols.volume_up_rounded;
  static const IconData volumeUpRounded = Symbols.volume_up_rounded;
  static const IconData warningAmberRounded = Symbols.warning_amber_rounded;
  static const IconData waterDrop = Symbols.water_drop_rounded;
  static const IconData wbCloudy = Symbols.wb_cloudy_rounded;
  static const IconData wbSunny = Symbols.wb_sunny_rounded;
  static const IconData wbTwilightRounded = Symbols.wb_twilight_rounded;
  static const IconData weatherSnowy = Symbols.weather_snowy_rounded;
  // FORK: quiz « Qui chante ? » v2, Material Symbols Rounded (J6e).
  static const IconData quizSpark = Symbols.auto_awesome_rounded; // FORK: quiz
  // FORK: listening modes « Conditions d'écoute » (J6f).
  static const IconData listeningNormal = Symbols.wb_sunny_rounded; // FORK
  static const IconData listeningWind = Symbols.air_rounded; // FORK
  static const IconData listeningBoost = Symbols.volume_up_rounded; // FORK
  static const IconData listeningCity = Symbols.location_city_rounded; // FORK
  static const IconData listeningSelected = Symbols.check_circle_rounded; // FORK
}
