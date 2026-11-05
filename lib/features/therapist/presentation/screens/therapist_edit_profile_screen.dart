import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/location_autocomplete_field.dart';
import '../../../../core/media/profile_photo.dart';
import '../../../../core/widgets/profile_photo_field.dart';
import '../../../../core/widgets/shared_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/widgets/auth_form_widgets.dart';
import '../../data/models/therapist_models.dart';
import '../providers/therapist_providers.dart';
import '../../../../core/validation/validators.dart';

/// Edit the therapist's public profile.
///
/// `PUT /therapists/me/profile` writes name/phone/city/specialty to User and
/// the professional fields to Therapist, so one save covers both.
class TherapistEditProfileScreen extends ConsumerStatefulWidget {
  const TherapistEditProfileScreen({super.key});

  @override
  ConsumerState<TherapistEditProfileScreen> createState() =>
      _TherapistEditProfileScreenState();
}

class _TherapistEditProfileScreenState
    extends ConsumerState<TherapistEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _specialty = TextEditingController();
  final _price = TextEditingController();
  final _experience = TextEditingController();
  final _bio = TextEditingController();

  /// A photo picked or removed but not yet saved; committed by Save.
  ProfilePhotoDraft _photo = ProfilePhotoDraft.untouched;

  bool _seeded = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _city,
      _specialty,
      _price,
      _experience,
      _bio,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Fills the form once, the first time the profile arrives — refetches must
  /// not clobber what the therapist has typed.
  void _seed(TherapistProfileDto profile) {
    if (_seeded) return;
    _seeded = true;
    _name.text = profile.name;
    _phone.text = Validators.normalizePhone(profile.phone);
    _city.text = profile.city;
    _specialty.text = profile.specialty;
    _price.text = profile.price == 0 ? '' : profile.price.toStringAsFixed(0);
    _experience.text = profile.experience == 0 ? '' : '${profile.experience}';
    _bio.text = profile.bio;
  }

  Future<void> _save() async {
    // A name-only check let a blank rate or a typo in years of experience
    // through to the API, where it failed as an unexplained error.
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await ref
        .read(therapistActionsProvider)
        .updateProfile(
          TherapistProfileUpdateDto(
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            city: _city.text.trim(),
            specialty: _specialty.text.trim(),
            price: double.tryParse(_price.text.trim()),
            experience: int.tryParse(_experience.text.trim()),
            bio: _bio.text.trim(),
          ),
        );

    if (!mounted) return;

    final failure = result.getLeft().toNullable();
    if (failure != null) {
      setState(() {
        _busy = false;
        _error = failure.message;
      });
      return;
    }

    if (_photo.changed) {
      final userId = ref.read(currentUserProvider)?.id;
      final photo = userId == null
          ? null
          : await commitProfilePhoto(
              ref.read(profilePhotoRepositoryProvider),
              owner: PhotoOwner.therapist,
              ownerId: userId,
              draft: _photo,
            );
      if (!mounted) return;
      final photoFailure = photo?.getLeft().toNullable();
      if (photoFailure != null) {
        // The fields saved; say so, and stay open with the photo still
        // pending so Save tries it again.
        setState(() {
          _busy = false;
          _error = context.l10n.photoUploadFailed(photoFailure.message);
        });
        return;
      }
      // The header on the account screen reads the photo from the session
      // user, and the form from the profile -- refresh both.
      ref.invalidate(therapistProfileProvider);
      await ref.read(authActionsProvider).getCurrentUser();
      if (!mounted) return;
    }

    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.editProfileSaved)));
    _close();
  }

  void _close() =>
      context.canPop() ? context.pop() : context.go('/therapist/account');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = ref.watch(therapistProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: profile.when(
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(title: l10n.editProfileTitle, onBack: _close),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
                child: SkeletonList(count: 4, itemHeight: 72),
              ),
            ],
          ),
          error: (e, _) => Column(
            children: [
              PageHeader(title: l10n.editProfileTitle, onBack: _close),
              Expanded(
                child: ErrorStateView(
                  failure: e is Failure ? e : const UnknownFailure(),
                  onRetry: () => ref.invalidate(therapistProfileProvider),
                ),
              ),
            ],
          ),
          data: (data) {
            _seed(data);
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  PageHeader(title: l10n.editProfileTitle, onBack: _close),
                  const SizedBox(height: 20),
                  ProfilePhotoField(
                    initials: ref.watch(currentUserProvider)?.initials ?? '?',
                    currentUrl: data.photo,
                    currentThumbUrl: data.photoThumb,
                    draft: _photo,
                    enabled: !_busy,
                    onChanged: (draft) => setState(() => _photo = draft),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.editProfileSectionProfessional,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 12),
                  LabeledField(
                    label: l10n.fieldFullNameLabel,
                    hint: l10n.fieldFullNameHintTherapist,
                    controller: _name,
                    validator: Validators.fullName(l10n),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  LabeledField(
                    label: l10n.fieldPhoneLabel,
                    hint: l10n.fieldPhoneHint,
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: Validators.phoneInputFormatters,
                    validator: Validators.phone(l10n),
                  ),
                  const SizedBox(height: 12),
                  LabeledField(
                    label: 'SPECIALIZATIONS',
                    hint: l10n.therapistFieldSpecializationHint,
                    controller: _specialty,
                    validator: Validators.required(l10n, l10n.fieldSpecialisation),
                  ),
                  const SizedBox(height: 12),
                  LocationAutocompleteField(
                    label: l10n.therapistFieldServiceAreaLabel,
                    hint: l10n.cityLalitpur,
                    controller: _city,
                    detail: LocationDetail.city,
                    validator: Validators.required(l10n, l10n.fieldServiceArea),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: LabeledField(
                          label: l10n.therapistFieldRateLabel,
                          hint: '1500',
                          controller: _price,
                          keyboardType: TextInputType.number,
                          validator: Validators.amount(
                            l10n,
                            l10n.fieldRatePerSession,
                            min: 100,
                            max: 100000,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LabeledField(
                          label: l10n.therapistFieldYearsLabel,
                          hint: '6',
                          controller: _experience,
                          keyboardType: TextInputType.number,
                          validator: Validators.wholeNumber(
                            l10n,
                            l10n.fieldYearsOfExperience,
                            max: 70,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LabeledField(
                    label: l10n.therapistFieldBioLabel,
                    hint: l10n.therapistFieldBioHint,
                    controller: _bio,
                    validator: Validators.optional(
                      Validators.longText(l10n, l10n.fieldShortBio, min: 20, max: 600),
                    ),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 12),
                  // Certifications are returned by the profile endpoint but there
                  // is no way to replace them from here — that is part of the
                  // application flow the admin reviews.
                  // TODO(api): document replacement after approval.
                  _ReadOnlyNote(
                    label: l10n.therapistCertificationsLabel,
                    value: l10n.therapistCertificationsNote,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AuthErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _busy ? null : _close,
                            child: Text(l10n.actionCancel),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _busy ? null : _save,
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.ink,
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
            );
          },
        ),
      ),
    );
  }
}

class _ReadOnlyNote extends StatelessWidget {
  const _ReadOnlyNote({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.mist,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.inkMid,
            ),
          ),
        ),
      ],
    );
  }
}
