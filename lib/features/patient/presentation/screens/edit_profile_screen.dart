import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sahayatri_care_connect/core/location/place_description.dart';
import 'package:sahayatri_care_connect/core/theme/app_theme_field.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/location_autocomplete_field.dart';
import '../../../../core/media/profile_photo.dart';
import '../../../../core/widgets/profile_photo_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/validation/validators.dart';
import '../../data/models/care_models.dart';
import '../providers/patient_profile_providers.dart';

/// Edit the signed-in patient's profile.
///
/// Two rows back this screen, and the split is not cosmetic. `PUT /auth/me`
/// owns the account (name, phone, city) — the header and every greeting read
/// from it. `PUT /patients/me/profile` owns the care record (home address,
/// medical history, primary concern). The screen used to write only the first,
/// so home address, primary concern, date of birth and gender were all drawn
/// disabled with a "coming soon" marker while the endpoint behind three of
/// them already existed.
///
/// Date of birth and gender stay read-only on purpose: `PatientProfileUpdate`
/// dropped both when they became admin-only, so a client that sends either
/// gets a 422. They are shown with their real value and a note saying where
/// they are set, rather than an empty box implying a missing feature.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _city;
  final _address = TextEditingController();

  /// A photo picked or removed but not yet saved. Committed by Save, like
  /// every other field here.
  ProfilePhotoDraft _photo = ProfilePhotoDraft.untouched;
  final _history = TextEditingController();
  final _condition = TextEditingController();

  /// The care fields arrive a moment after the account ones, so they are
  /// filled once when the fetch lands instead of on every rebuild — otherwise
  /// a rebuild mid-edit would overwrite what the patient is typing.
  bool _careFilled = false;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider);
    _name = TextEditingController(text: user?.name ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    _phone = TextEditingController(
      text: Validators.normalizePhone(user?.phone),
    );
    _city = TextEditingController(text: user?.city ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _email,
      _phone,
      _city,
      _address,
      _history,
      _condition,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fillCareFields(PatientProfileDto? profile) {
    if (_careFilled) return;
    _careFilled = true;
    if (profile == null) return;
    _address.text = profile.address ?? '';
    _history.text = profile.history ?? '';
    _condition.text = profile.condition ?? '';
    // The account row wins for city when it has one; the profile row is the
    // fallback for patients whose city was only ever set during onboarding.
    if (_city.text.isEmpty) _city.text = profile.city;
  }

  Future<void> _save() async {
    // Was a name-only check, so a malformed phone number reached the API and
    // came back as a 422 the screen showed as a bare error string.
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final name = _name.text.trim();
    final city = _city.text.trim();

    // Account first. If this fails there is nothing to roll back, whereas
    // saving the care record and then failing here would leave the two rows
    // disagreeing about the patient's name.
    final account = await ref
        .read(authActionsProvider)
        .updateProfile(name: name, city: city, phone: _phone.text.trim());

    if (!mounted) return;

    final accountFailure = account.getLeft().toNullable();
    if (accountFailure != null) {
      setState(() {
        _busy = false;
        _error = accountFailure.message;
      });
      return;
    }

    final care = await ref
        .read(patientProfileActionsProvider)
        .save(
          PatientProfileUpdateDto(
            // Mirrored so the care record does not keep a stale name: the
            // profile row has its own copy and nothing else syncs them.
            name: name,
            city: city,
            address: _address.text.trim(),
            history: _history.text.trim(),
            condition: _condition.text.trim(),
          ),
        );

    if (!mounted) return;

    final careFailure = care.getLeft().toNullable();
    if (careFailure != null) {
      setState(() {
        _busy = false;
        _error = careFailure.message;
      });
      return;
    }

    ref.read(authActionsProvider).applyUser(account.getRight().toNullable()!);

    // The photo goes last, after the fields. A patient with no care record yet
    // has no profile row for the photo to attach to, and the care save above
    // is what creates it -- so an upload any earlier would 404 for exactly the
    // patient who has never saved a profile.
    if (_photo.changed) {
      final userId = ref.read(currentUserProvider)?.id;
      final photo = userId == null
          ? null
          : await commitProfilePhoto(
              ref.read(profilePhotoRepositoryProvider),
              owner: PhotoOwner.patient,
              ownerId: userId,
              draft: _photo,
            );
      if (!mounted) return;
      final photoFailure = photo?.getLeft().toNullable();
      if (photoFailure != null) {
        // The fields did save, and the screen says so rather than leaving the
        // person to wonder which half worked. It stays open, with the photo
        // still pending, so Save tries it again.
        setState(() {
          _busy = false;
          _error = context.l10n.photoUploadFailed(photoFailure.message);
        });
        return;
      }
      ref.invalidate(patientProfileProvider);
    }

    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.editProfileSaved)));
    _close();
  }

  void _close() =>
      context.canPop() ? context.pop() : context.go('/patient/account');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppTypography.textTheme;
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(patientProfileProvider);

    profile.whenData(_fillCareFields);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        // The same rounded white fields as signup and login, applied to every
        // text field in the form.
        child: Theme(
          data: appFieldTheme(Theme.of(context)),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                // Back arrow
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: _close,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 28,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                Text(
                  l10n.editProfileTitle,
                  style: text.titleLarge!.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),

                // --- Avatar -------------------------------------------------
                ProfilePhotoField(
                  initials: user?.initials ?? '?',
                  currentUrl: profile.valueOrNull?.photo,
                  currentThumbUrl: profile.valueOrNull?.photoThumb,
                  draft: _photo,
                  enabled: !_busy,
                  onChanged: (draft) => setState(() => _photo = draft),
                ),
                const SizedBox(height: 24),

                // --- Personal -----------------------------------------------
                _SectionTitle(l10n.editProfileSectionPersonal),
                const SizedBox(height: 14),

                _FieldLabel(l10n.fieldFullNameLabel),
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(
                    hintText: l10n.fieldFullNameHintPatient,
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                  ),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: Validators.fullName(l10n),
                ),
                const SizedBox(height: 16),

                // Email identifies the account; changing it would need a
                // re-verification flow the backend does not expose.
                _ReadOnlyField(
                  label: l10n.fieldEmailLabel,
                  value: _email.text,
                  icon: Icons.mail_outline,
                ),
                const SizedBox(height: 16),

                _FieldLabel(l10n.fieldPhoneLabel),
                TextFormField(
                  controller: _phone,
                  decoration: InputDecoration(
                    hintText: l10n.fieldPhoneHint,
                    prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: Validators.phoneInputFormatters,
                  textInputAction: TextInputAction.next,
                  validator: Validators.optional(Validators.phone(l10n)),
                ),
                const SizedBox(height: 16),

                _LockedField(
                  label: l10n.fieldDateOfBirthLabel,
                  value: formatFullDateFromString(
                    profile.valueOrNull?.dob,
                    l10n,
                  ),
                  loading: profile.isLoading,
                  icon: Icons.cake_outlined,
                ),
                const SizedBox(height: 16),
                _LockedField(
                  label: l10n.fieldGenderLabel,
                  // 'Any' is the column default, which reads as "not asked"
                  // rather than a gender the patient chose.
                  value: switch (profile.valueOrNull?.gender) {
                    null || '' || 'Any' => null,
                    final g => g,
                  },
                  loading: profile.isLoading,
                  icon: Icons.wc_outlined,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.editProfileLockedNote,
                  style: text.bodySmall!.copyWith(height: 1.4),
                ),
                const SizedBox(height: 28),

                // --- Care ---------------------------------------------------
                _SectionTitle(l10n.editProfileSectionCare),
                const SizedBox(height: 14),

                // City drives therapist matching, so it is its own field.
                // It used to be the one labelled "home address", which meant a
                // patient typing a street address broke their own search.
                _FieldLabel(l10n.fieldCityAreaLabel),
                LocationAutocompleteField(
                  controller: _city,
                  detail: LocationDetail.city,
                  decoration: InputDecoration(
                    hintText: l10n.fieldCityAreaHint,
                    prefixIcon: const Icon(
                      Icons.location_city_outlined,
                      size: 20,
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: Validators.serviceCity(
                    l10n,
                    cities: supportedCities,
                  ),
                ),
                const SizedBox(height: 16),

                if (profile.isLoading && !_careFilled)
                  const SkeletonBox(height: 200)
                else ...[
                  _FieldLabel(l10n.fieldHomeAddressLabel),
                  LocationAutocompleteField(
                    controller: _address,
                    detail: LocationDetail.address,
                    decoration: InputDecoration(
                      hintText: l10n.fieldHomeAddressHint,
                      prefixIcon: const Icon(Icons.home_outlined, size: 20),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  _FieldLabel(l10n.fieldPrimaryConcernLabel),
                  TextFormField(
                    controller: _condition,
                    decoration: InputDecoration(
                      hintText: l10n.fieldPrimaryConcernHint,
                      prefixIcon: const Icon(Icons.healing_outlined, size: 20),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  _FieldLabel(l10n.fieldMedicalHistoryLabel),
                  TextFormField(
                    controller: _history,
                    decoration: InputDecoration(
                      hintText: l10n.fieldMedicalHistoryHint,
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 28),

                // --- Actions ------------------------------------------------
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _busy ? null : _close,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.ink,
                            side: BorderSide(color: appSageBorder),
                            // Buttons default to labelLarge (mono, spaced), so
                            // the style has to be given here.
                            textStyle: text.titleSmall,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.tile,
                              ),
                            ),
                          ),
                          child: Text(l10n.actionCancel),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.pine,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.pine.withAlpha(
                              90,
                            ),
                            disabledForegroundColor: Colors.white,
                            elevation: 0,
                            textStyle: text.titleSmall,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.tile,
                              ),
                            ),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(l10n.actionSaveChanges),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pieces ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTypography.textTheme.titleMedium!.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// A plain label above a field. Kept (rather than a hint alone) because the
/// fields here arrive filled, and a hint disappears the moment there is text.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppTypography.textTheme.titleSmall!.copyWith(
          fontSize: 13,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

/// A field whose value exists but cannot be edited here.
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            color: AppColors.mist,
            borderRadius: BorderRadius.circular(AppRadii.tile),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.inkMid),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium,
                ),
              ),
              const Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: AppColors.inkMute,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A field the patient may read but only an admin may write.
///
/// Distinct from [_ReadOnlyField] by the marker beside its label: this is not
/// "not editable on this screen", it is "not editable by you", and the note
/// under the group says who to ask.
class _LockedField extends StatelessWidget {
  const _LockedField({
    required this.label,
    required this.value,
    required this.icon,
    this.loading = false,
  });

  final String label;
  final String? value;
  final IconData icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final text = AppTypography.textTheme;
    final shown = value?.trim();
    final empty = shown == null || shown.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Text(
                label,
                style: text.titleSmall!.copyWith(
                  fontSize: 13,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.l10n.fieldSetAtSignup,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall!.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        if (loading)
          const SkeletonBox(height: 52, radius: AppRadii.tile)
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(
              color: AppColors.mist,
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.inkMid),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    empty ? context.l10n.fieldNotRecorded : shown,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium!.copyWith(
                      color: empty ? AppColors.inkMute : AppColors.inkMid,
                    ),
                  ),
                ),
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: AppColors.inkMute,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerPale,
        borderRadius: BorderRadius.circular(AppRadii.tile),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.textTheme.bodySmall!.copyWith(
                height: 1.4,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
