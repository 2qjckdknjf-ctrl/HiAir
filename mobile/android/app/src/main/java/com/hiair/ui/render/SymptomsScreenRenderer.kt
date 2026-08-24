package com.hiair.ui.render

import android.graphics.Typeface
import android.text.Editable
import android.text.TextWatcher
import android.view.Gravity
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.CheckBox
import android.widget.EditText
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.Spinner
import android.widget.TextView
import com.hiair.StoreScreenshotMode
import com.hiair.ui.design.HiAirColors
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.design.HiAirSpacing
import com.hiair.ui.design.Tokens
import com.hiair.ui.symptoms.SymptomCategory
import com.hiair.ui.symptoms.SymptomLogState
import com.hiair.ui.theme.V2Ui

internal object SymptomsScreenRenderer {
    fun render(ctx: RenderContext) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val bodyContainer = ctx.bodyContainer

        val seeded = StoreScreenshotMode.active && rootShell.symptomLogViewModel.state.taxonomy != null
        if (seeded) {
            SymptomsDeepGlassLayout.render(ctx, rootShell.symptomLogViewModel.state)
            return
        }

        if (HiAirComponents.shouldShowCompactBrandHeader()) {
            bodyContainer.addView(HiAirComponents.brandHeader(activity))
        }
        ctx.titleView.text = ctx.l("title.symptoms")
        bodyContainer.addView(
            V2Ui.styledSecondaryText(activity, ctx.l("symptoms.subtitle")).apply { textSize = 13f },
        )
        bodyContainer.addView(
            V2Ui.styledSecondaryText(activity, ctx.l("symptoms.streak")).apply {
                textSize = 12f
                setPadding(
                    V2Ui.dp(activity, 10),
                    V2Ui.dp(activity, 6),
                    V2Ui.dp(activity, 10),
                    V2Ui.dp(activity, 6),
                )
                background = HiAirComponents.chipBackground(activity)
            },
        )

        val contentHost = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        }
        val symptomsHost = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        }
        bodyContainer.addView(contentHost)

        fun paintSymptoms(state: SymptomLogState, profileReady: Boolean) {
            symptomsHost.removeAllViews()
            if (state.taxonomy == null) return
            filteredCategoryCards(ctx).forEach { category ->
                symptomsHost.addView(buildCategoryCard(ctx, state, category, ::paintSymptoms))
            }
            symptomsHost.addView(buildSeverityCard(ctx, state, ::paintSymptoms))
            symptomsHost.addView(buildSubmitSection(ctx, state, profileReady, ::paintSymptoms))
        }

        fun paint(state: SymptomLogState, profileReady: Boolean) {
            contentHost.removeAllViews()
            if (state.taxonomyLoading) {
                contentHost.addView(
                    HiAirComponents.loadingState(activity, ctx.l("symptoms.taxonomy_loading")),
                )
                return
            }
            if (state.taxonomyFailed) {
                contentHost.addView(
                    HiAirComponents.cardContainer(activity).apply {
                        addView(V2Ui.styledSecondaryText(activity, ctx.l("symptoms.taxonomy_failed")))
                        addView(
                            HiAirComponents.secondaryButton(activity, ctx.l("common.retry")).apply {
                                setOnClickListener { loadTaxonomy(ctx, ::paint) }
                            },
                        )
                    },
                )
                return
            }

            state.taxonomy?.safetyNotice?.takeIf { it.isNotBlank() }?.let { notice ->
                contentHost.addView(
                    HiAirComponents.cardContainer(activity).apply {
                        addView(V2Ui.styledSecondaryText(activity, notice).apply { textSize = 12f })
                    },
                )
            }

            if (!profileReady) {
                contentHost.addView(buildProfileEmptyCard(ctx))
            }

            if (state.favorites.isNotEmpty() && state.taxonomy != null) {
                contentHost.addView(buildFavoritesCard(ctx, state, ::paintSymptoms))
            }

            if (state.taxonomy != null) {
                contentHost.addView(buildSearchCard(ctx, state, ::paintSymptoms))
                contentHost.addView(symptomsHost)
                paintSymptoms(state, profileReady)
            }
        }

        contentHost.addView(HiAirComponents.loadingState(activity, ctx.l("symptoms.taxonomy_loading")))
        loadTaxonomy(ctx, ::paint)
    }

    private fun loadTaxonomy(
        ctx: RenderContext,
        paint: (SymptomLogState, Boolean) -> Unit,
    ) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val viewModel = rootShell.symptomLogViewModel
        val settings = rootShell.settingsViewModel.state

        Thread {
            val profileId = rootShell.settingsViewModel.ensureProfile()
            if (profileId != null) {
                viewModel.updateProfileId(profileId)
            }
            viewModel.loadTaxonomy(settings.preferredLanguage)
            val profileReady = !profileId.isNullOrBlank()
            activity.runOnUiThread {
                paint(viewModel.state, profileReady)
            }
        }.start()
    }

    private fun buildProfileEmptyCard(ctx: RenderContext): LinearLayout {
        val activity = ctx.activity
        return HiAirComponents.cardContainer(activity).apply {
            addView(HiAirComponents.sectionTitle(activity, ctx.l("symptoms.empty.title")))
            addView(V2Ui.styledSecondaryText(activity, ctx.l("symptoms.empty.body")))
            addView(
                HiAirComponents.secondaryButton(activity, ctx.l("planner.empty.no_profile.cta")).apply {
                    setOnClickListener {
                        Thread {
                            ctx.rootShell.settingsViewModel.ensureProfile()
                            ctx.activity.runOnUiThread { ctx.rerender() }
                        }.start()
                    }
                },
            )
        }
    }

    private fun buildFavoritesCard(
        ctx: RenderContext,
        state: SymptomLogState,
        repaintSymptoms: (SymptomLogState, Boolean) -> Unit,
    ): LinearLayout {
        val activity = ctx.activity
        val viewModel = ctx.rootShell.symptomLogViewModel
        return HiAirComponents.cardContainer(activity).apply {
            addView(HiAirComponents.sectionTitle(activity, ctx.l("symptoms.favorites")))
            state.favorites.chunked(2).forEach { rowTypes ->
                addView(
                    LinearLayout(activity).apply {
                        orientation = LinearLayout.HORIZONTAL
                        rowTypes.forEach { type ->
                            addView(
                                favoriteButton(ctx, viewModel.labelFor(type)).apply {
                                    setOnClickListener {
                                        submitFavorite(ctx, type, repaintSymptoms)
                                    }
                                    layoutParams = LinearLayout.LayoutParams(
                                        0,
                                        LinearLayout.LayoutParams.WRAP_CONTENT,
                                        1f,
                                    ).apply {
                                        marginEnd = V2Ui.dp(activity, 6)
                                        topMargin = V2Ui.dp(activity, 6)
                                    }
                                },
                            )
                        }
                        if (rowTypes.size == 1) {
                            addView(
                                LinearLayout(activity).apply {
                                    layoutParams = LinearLayout.LayoutParams(0, 0, 1f)
                                },
                            )
                        }
                    },
                )
            }
        }
    }

    private fun favoriteButton(ctx: RenderContext, label: String): TextView {
        val activity = ctx.activity
        return TextView(activity).apply {
            text = label
            textSize = 14f
            gravity = Gravity.CENTER
            setTextColor(Tokens.Text.primary)
            minHeight = V2Ui.dp(activity, 44)
            setPadding(
                V2Ui.dp(activity, 10),
                V2Ui.dp(activity, 10),
                V2Ui.dp(activity, 10),
                V2Ui.dp(activity, 10),
            )
            background = HiAirComponents.chipBackground(activity)
        }
    }

    private fun submitFavorite(
        ctx: RenderContext,
        symptomType: String,
        repaintSymptoms: (SymptomLogState, Boolean) -> Unit,
    ) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val viewModel = rootShell.symptomLogViewModel
        Thread {
            val profileId = rootShell.settingsViewModel.ensureProfile()
            if (profileId != null) {
                viewModel.updateProfileId(profileId)
            }
            val settings = rootShell.settingsViewModel.state
            viewModel.quickLog(
                userId = settings.userId,
                accessToken = settings.accessToken.ifBlank { null },
                symptomType = symptomType,
                preferredLanguage = settings.preferredLanguage,
            )
            activity.runOnUiThread {
                repaintSymptoms(viewModel.state, !profileId.isNullOrBlank())
            }
        }.start()
    }

    private fun buildSearchCard(
        ctx: RenderContext,
        state: SymptomLogState,
        repaintSymptoms: (SymptomLogState, Boolean) -> Unit,
    ): LinearLayout {
        val activity = ctx.activity
        val viewModel = ctx.rootShell.symptomLogViewModel
        return HiAirComponents.cardContainer(activity).apply {
            val searchInput = HiAirComponents.inputField(activity, ctx.l("symptoms.search")).apply {
                setText(state.searchText)
                addTextChangedListener(
                    object : TextWatcher {
                        override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
                        override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
                        override fun afterTextChanged(s: Editable?) {
                            val newText = s?.toString().orEmpty()
                            if (newText == viewModel.state.searchText) return
                            viewModel.setSearchText(newText)
                            repaintSymptoms(viewModel.state, viewModel.state.profileId.isNotBlank())
                        }
                    },
                )
            }
            addView(searchInput)
            addView(categoryFilterRow(ctx, state, repaintSymptoms))
        }
    }

    private fun categoryFilterRow(
        ctx: RenderContext,
        state: SymptomLogState,
        repaintSymptoms: (SymptomLogState, Boolean) -> Unit,
    ): HorizontalScrollView {
        val activity = ctx.activity
        val viewModel = ctx.rootShell.symptomLogViewModel
        val chipRow = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, V2Ui.dp(activity, HiAirSpacing.xs), 0, 0)
        }
        chipRow.addView(
            filterChip(ctx, ctx.l("symptoms.all_categories"), selected = state.selectedCategory == null) {
                viewModel.setSelectedCategory(null)
                repaintSymptoms(viewModel.state, viewModel.state.profileId.isNotBlank())
            },
        )
        state.taxonomy?.categories.orEmpty().forEach { category ->
            chipRow.addView(
                filterChip(ctx, category.label, selected = state.selectedCategory == category.id) {
                    viewModel.setSelectedCategory(category.id)
                    repaintSymptoms(viewModel.state, viewModel.state.profileId.isNotBlank())
                },
            )
        }
        return HorizontalScrollView(activity).apply {
            isHorizontalScrollBarEnabled = false
            addView(chipRow)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = V2Ui.dp(activity, HiAirSpacing.xs)
            }
        }
    }

    private fun filterChip(
        ctx: RenderContext,
        label: String,
        selected: Boolean,
        onClick: () -> Unit,
    ): TextView {
        val activity = ctx.activity
        return TextView(activity).apply {
            text = label
            textSize = 12f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(if (selected) Tokens.Text.primary else Tokens.Text.secondary)
            setPadding(
                V2Ui.dp(activity, 12),
                V2Ui.dp(activity, 8),
                V2Ui.dp(activity, 12),
                V2Ui.dp(activity, 8),
            )
            background = HiAirComponents.tileBackground(activity, selected = selected)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                marginEnd = V2Ui.dp(activity, 8)
            }
            setOnClickListener { onClick() }
        }
    }

    private fun filteredCategoryCards(ctx: RenderContext): List<SymptomCategory> {
        return ctx.rootShell.symptomLogViewModel.filteredCategories()
    }

    private fun buildCategoryCard(
        ctx: RenderContext,
        state: SymptomLogState,
        category: SymptomCategory,
        repaintSymptoms: (SymptomLogState, Boolean) -> Unit,
    ): LinearLayout {
        val activity = ctx.activity
        val viewModel = ctx.rootShell.symptomLogViewModel
        val expanded = state.expandedCategoryIds.contains(category.id) || state.searchText.isNotBlank()
        return HiAirComponents.cardContainer(activity).apply {
            addView(
                TextView(activity).apply {
                    text = "${category.label} (${category.symptoms.size})"
                    textSize = 16f
                    setTypeface(typeface, Typeface.BOLD)
                    setTextColor(Tokens.Text.primary)
                    minHeight = V2Ui.dp(activity, 44)
                    setPadding(0, V2Ui.dp(activity, 8), 0, V2Ui.dp(activity, 8))
                    setOnClickListener {
                        viewModel.toggleCategory(category.id)
                        repaintSymptoms(viewModel.state, viewModel.state.profileId.isNotBlank())
                    }
                },
            )
            if (!expanded) {
                return@apply
            }
            category.symptoms.chunked(2).forEach { rowItems ->
                addView(
                    LinearLayout(activity).apply {
                        orientation = LinearLayout.HORIZONTAL
                        rowItems.forEach { item ->
                            val selected = state.selectedType == item.symptomType
                            addView(
                                LinearLayout(activity).apply {
                                    orientation = LinearLayout.HORIZONTAL
                                    addView(
                                        symptomPill(
                                            activity = activity,
                                            label = if (item.redFlag) "⚠ ${item.label}" else item.label,
                                            selected = selected,
                                        ).apply {
                                            setOnClickListener {
                                                viewModel.selectSymptom(item.symptomType, item.redFlag)
                                                repaintSymptoms(viewModel.state, viewModel.state.profileId.isNotBlank())
                                            }
                                            layoutParams = LinearLayout.LayoutParams(
                                                0,
                                                LinearLayout.LayoutParams.WRAP_CONTENT,
                                                1f,
                                            )
                                        },
                                    )
                                    addView(
                                        TextView(activity).apply {
                                            text = if (state.favorites.contains(item.symptomType)) "★" else "☆"
                                            textSize = 18f
                                            gravity = Gravity.CENTER
                                            setTextColor(Tokens.Text.secondary)
                                            contentDescription = ctx.l("symptoms.favorites")
                                            minWidth = V2Ui.dp(activity, 36)
                                            setOnClickListener {
                                                viewModel.toggleFavorite(item.symptomType)
                                                repaintSymptoms(viewModel.state, viewModel.state.profileId.isNotBlank())
                                                ctx.rerender()
                                            }
                                        },
                                    )
                                    layoutParams = LinearLayout.LayoutParams(
                                        0,
                                        LinearLayout.LayoutParams.WRAP_CONTENT,
                                        1f,
                                    ).apply {
                                        marginEnd = V2Ui.dp(activity, 6)
                                        topMargin = V2Ui.dp(activity, 6)
                                    }
                                },
                            )
                        }
                        if (rowItems.size == 1) {
                            addView(LinearLayout(activity).apply {
                                layoutParams = LinearLayout.LayoutParams(0, 0, 1f)
                            })
                        }
                    },
                )
            }
        }
    }

    private fun symptomPill(
        activity: android.app.Activity,
        label: String,
        selected: Boolean,
    ): TextView {
        return TextView(activity).apply {
            text = label
            textSize = 13f
            gravity = Gravity.CENTER
            minHeight = V2Ui.dp(activity, 44)
            setTextColor(if (selected) Tokens.Text.primary else Tokens.Text.secondary)
            setPadding(
                V2Ui.dp(activity, 8),
                V2Ui.dp(activity, 10),
                V2Ui.dp(activity, 8),
                V2Ui.dp(activity, 10),
            )
            background = HiAirComponents.tileBackground(activity, selected = selected)
        }
    }

    private fun buildSeverityCard(
        ctx: RenderContext,
        state: SymptomLogState,
        repaint: (SymptomLogState, Boolean) -> Unit,
    ): LinearLayout {
        val activity = ctx.activity
        val viewModel = ctx.rootShell.symptomLogViewModel
        return HiAirComponents.cardContainer(activity).apply {
            addView(V2Ui.styledBodyText(activity, ctx.l("symptoms.severity")))
            addView(
                V2Ui.styledSecondaryText(activity, severityCaption(ctx, state.severity)).apply {
                    textSize = 12f
                },
            )
            addView(
                LinearLayout(activity).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_HORIZONTAL
                    (1..5).forEach { value ->
                        val selected = state.severity == value
                        addView(
                            TextView(activity).apply {
                                text = value.toString()
                                textSize = 15f
                                gravity = Gravity.CENTER
                                setTextColor(if (selected) Tokens.Text.primary else Tokens.Text.secondary)
                                layoutParams = LinearLayout.LayoutParams(
                                    V2Ui.dp(activity, 40),
                                    V2Ui.dp(activity, 40),
                                ).apply {
                                    marginEnd = V2Ui.dp(activity, 8)
                                }
                                background = HiAirComponents.tileBackground(activity, selected = selected)
                                setOnClickListener {
                                    viewModel.setSeverity(value)
                                    repaint(viewModel.state, viewModel.state.profileId.isNotBlank())
                                }
                                contentDescription =
                                    "${ctx.l("symptoms.severity")} $value, ${severityCaption(ctx, value)}"
                            },
                        )
                    }
                },
            )
            addView(V2Ui.styledBodyText(activity, ctx.l("symptoms.location")).apply {
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ).apply {
                    topMargin = V2Ui.dp(activity, HiAirSpacing.sm)
                }
            })
            addView(locationPickerRow(ctx, state, repaint))
            addView(
                buildStringSpinnerRow(
                    ctx = ctx,
                    labelKey = "symptoms.frequency",
                    options = listOf(
                        "unspecified" to ctx.l("symptoms.frequency.any"),
                        "once" to ctx.l("symptoms.frequency.once"),
                        "intermittent" to ctx.l("symptoms.frequency.intermittent"),
                        "constant" to ctx.l("symptoms.frequency.constant"),
                    ),
                    selectedValue = state.frequency,
                    onSelected = { viewModel.setFrequency(it) },
                ).apply {
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                    ).apply {
                        topMargin = V2Ui.dp(activity, HiAirSpacing.sm)
                    }
                },
            )
            addView(
                buildIntSpinnerRow(
                    ctx = ctx,
                    labelKey = "symptoms.duration",
                    options = listOf(
                        0 to ctx.l("symptoms.duration.any"),
                        15 to ctx.l("symptoms.duration.15m"),
                        60 to ctx.l("symptoms.duration.1h"),
                        180 to ctx.l("symptoms.duration.3h"),
                        1440 to ctx.l("symptoms.duration.day"),
                    ),
                    selectedValue = state.durationMinutes,
                    onSelected = { viewModel.setDurationMinutes(it) },
                ),
            )
            addView(
                CheckBox(activity).apply {
                    text = ctx.l("symptoms.ongoing")
                    isChecked = state.ongoing
                    setTextColor(Tokens.Text.primary)
                    setOnCheckedChangeListener { _, checked ->
                        viewModel.setOngoing(checked)
                    }
                },
            )
            addView(
                buildStringSpinnerRow(
                    ctx = ctx,
                    labelKey = "symptoms.activity",
                    options = listOf(
                        "unspecified" to ctx.l("symptoms.activity.any"),
                        "rest" to ctx.l("symptoms.activity.rest"),
                        "walk" to ctx.l("symptoms.activity.walk"),
                        "exercise" to ctx.l("symptoms.activity.exercise"),
                        "work" to ctx.l("symptoms.activity.work"),
                        "sleep" to ctx.l("symptoms.activity.sleep"),
                    ),
                    selectedValue = state.activityAtOnset,
                    onSelected = { viewModel.setActivityAtOnset(it) },
                ),
            )
            addView(
                buildStringSpinnerRow(
                    ctx = ctx,
                    labelKey = "symptoms.hydration",
                    options = listOf(
                        "unspecified" to ctx.l("symptoms.hydration.any"),
                        "low" to ctx.l("symptoms.hydration.low"),
                        "adequate" to ctx.l("symptoms.hydration.ok"),
                        "high" to ctx.l("symptoms.hydration.high"),
                    ),
                    selectedValue = state.hydrationState,
                    onSelected = { viewModel.setHydrationState(it) },
                ),
            )
            addView(
                CheckBox(activity).apply {
                    text = ctx.l("symptoms.medication")
                    isChecked = state.medicationTaken
                    setTextColor(Tokens.Text.primary)
                    setOnCheckedChangeListener { _, checked ->
                        viewModel.setMedicationTaken(checked)
                    }
                },
            )
            val triggerInput = HiAirComponents.inputField(activity, ctx.l("symptoms.trigger_optional")).apply {
                setText(state.suspectedTrigger)
                addTextChangedListener(
                    object : TextWatcher {
                        override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
                        override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
                        override fun afterTextChanged(s: Editable?) {
                            viewModel.setSuspectedTrigger(s?.toString().orEmpty())
                        }
                    },
                )
            }
            addView(triggerInput)
            val noteInput = HiAirComponents.inputField(activity, ctx.l("symptoms.note_optional")).apply {
                setText(state.note)
                minLines = 2
                addTextChangedListener(
                    object : TextWatcher {
                        override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
                        override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
                        override fun afterTextChanged(s: Editable?) {
                            viewModel.setNote(s?.toString().orEmpty())
                        }
                    },
                )
            }
            addView(noteInput)
            state.safetyNotice?.takeIf { it.isNotBlank() }?.let { notice ->
                addView(
                    V2Ui.styledSecondaryText(activity, notice).apply {
                        textSize = 12f
                        setTextColor(HiAirColors.Feedback.errorSoft)
                    },
                )
            }
        }
    }

    private fun locationPickerRow(
        ctx: RenderContext,
        state: SymptomLogState,
        repaint: (SymptomLogState, Boolean) -> Unit,
    ): LinearLayout {
        val activity = ctx.activity
        val viewModel = ctx.rootShell.symptomLogViewModel
        val options = listOf(
            "unspecified" to ctx.l("symptoms.location.any"),
            "indoors" to ctx.l("symptoms.location.indoors"),
            "outdoors" to ctx.l("symptoms.location.outdoors"),
        )
        return LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            options.forEach { (value, label) ->
                val selected = state.locationContext == value
                addView(
                    TextView(activity).apply {
                        text = label
                        textSize = 12f
                        gravity = Gravity.CENTER
                        setTextColor(if (selected) Tokens.Text.primary else Tokens.Text.secondary)
                        setPadding(
                            V2Ui.dp(activity, 8),
                            V2Ui.dp(activity, 10),
                            V2Ui.dp(activity, 8),
                            V2Ui.dp(activity, 10),
                        )
                        background = HiAirComponents.tileBackground(activity, selected = selected)
                        layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                            .apply {
                                marginEnd = V2Ui.dp(activity, 6)
                            }
                        setOnClickListener {
                            viewModel.setLocationContext(value)
                            repaint(viewModel.state, viewModel.state.profileId.isNotBlank())
                        }
                    },
                )
            }
        }
    }

    private fun buildSubmitSection(
        ctx: RenderContext,
        state: SymptomLogState,
        profileReady: Boolean,
        repaint: (SymptomLogState, Boolean) -> Unit,
    ): LinearLayout {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val viewModel = rootShell.symptomLogViewModel
        val canSubmit = profileReady && !state.loading && !state.selectedType.isNullOrBlank()
        return LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            addView(
                HiAirComponents.primaryButton(
                    activity,
                    if (state.loading) ctx.l("symptoms.saving") else ctx.l("symptoms.submit"),
                ).apply {
                    isEnabled = canSubmit
                    alpha = if (canSubmit) 1f else 0.5f
                    setOnClickListener {
                        if (!canSubmit) return@setOnClickListener
                        Thread {
                            val profileId = rootShell.settingsViewModel.ensureProfile()
                            if (profileId != null) {
                                viewModel.updateProfileId(profileId)
                            }
                            val settings = rootShell.settingsViewModel.state
                            viewModel.submit(
                                userId = settings.userId,
                                accessToken = settings.accessToken.ifBlank { null },
                                preferredLanguage = settings.preferredLanguage,
                            )
                            activity.runOnUiThread {
                                repaint(viewModel.state, !profileId.isNullOrBlank())
                            }
                        }.start()
                    }
                },
            )
            if (state.statusText.isNotBlank()) {
                addView(
                    V2Ui.styledSecondaryText(activity, state.statusText).apply {
                        textSize = 12f
                        val params = LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.MATCH_PARENT,
                            LinearLayout.LayoutParams.WRAP_CONTENT,
                        )
                        params.topMargin = V2Ui.dp(activity, HiAirSpacing.xs)
                        layoutParams = params
                    },
                )
            }
        }
    }

    private fun buildStringSpinnerRow(
        ctx: RenderContext,
        labelKey: String,
        options: List<Pair<String, String>>,
        selectedValue: String,
        onSelected: (String) -> Unit,
    ): LinearLayout {
        val activity = ctx.activity
        val labels = options.map { it.second }
        val values = options.map { it.first }
        val spinner = Spinner(activity).apply {
            adapter = ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, labels)
            val selectedIndex = values.indexOf(selectedValue).coerceAtLeast(0)
            setSelection(selectedIndex, false)
            onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(
                    parent: AdapterView<*>?,
                    view: View?,
                    position: Int,
                    id: Long,
                ) {
                    onSelected(values[position.coerceIn(values.indices)])
                }

                override fun onNothingSelected(parent: AdapterView<*>?) = Unit
            }
        }
        return LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            addView(V2Ui.styledBodyText(activity, ctx.l(labelKey)))
            addView(spinner)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = V2Ui.dp(activity, HiAirSpacing.xs)
            }
        }
    }

    private fun buildIntSpinnerRow(
        ctx: RenderContext,
        labelKey: String,
        options: List<Pair<Int, String>>,
        selectedValue: Int,
        onSelected: (Int) -> Unit,
    ): LinearLayout {
        val activity = ctx.activity
        val labels = options.map { it.second }
        val values = options.map { it.first }
        val spinner = Spinner(activity).apply {
            adapter = ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, labels)
            val selectedIndex = values.indexOf(selectedValue).coerceAtLeast(0)
            setSelection(selectedIndex, false)
            onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(
                    parent: AdapterView<*>?,
                    view: View?,
                    position: Int,
                    id: Long,
                ) {
                    onSelected(values[position.coerceIn(values.indices)])
                }

                override fun onNothingSelected(parent: AdapterView<*>?) = Unit
            }
        }
        return LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            addView(V2Ui.styledBodyText(activity, ctx.l(labelKey)))
            addView(spinner)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = V2Ui.dp(activity, HiAirSpacing.xs)
            }
        }
    }

    private fun severityCaption(ctx: RenderContext, value: Int): String {
        return when (value) {
            1, 2 -> ctx.l("symptoms.severity.mild")
            3 -> ctx.l("symptoms.severity.moderate")
            else -> ctx.l("symptoms.severity.severe")
        }
    }
}
