package com.codex.projector.launcher;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ResolveInfo;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.provider.Settings;
import android.view.Gravity;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.GridLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public final class MainActivity extends Activity {
    private static final int ACCENT = Color.rgb(112, 161, 255);
    private static final int PANEL = Color.rgb(29, 35, 48);
    private static final int TEXT = Color.rgb(239, 243, 250);
    private static final int MUTED = Color.rgb(166, 177, 198);

    private final SimpleDateFormat clockFormat = new SimpleDateFormat("HH:mm", Locale.getDefault());
    private TextView clock;
    private GridLayout appGrid;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN);
        getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_HIDDEN);
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        | View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
        setContentView(buildRoot());
    }

    @Override
    protected void onResume() {
        super.onResume();
        updateClock();
        if (appGrid != null) {
            populateApps();
        }
    }

    private View buildRoot() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(32), dp(24), dp(32), dp(20));
        root.setBackgroundColor(Color.rgb(16, 19, 24));

        LinearLayout header = new LinearLayout(this);
        header.setGravity(Gravity.CENTER_VERTICAL);

        TextView title = text("Projector Home", 30, TEXT);
        title.setTypeface(null, 1);
        header.addView(title, new LinearLayout.LayoutParams(0, dp(54), 1f));

        clock = text("", 28, TEXT);
        clock.setGravity(Gravity.CENTER_VERTICAL | Gravity.RIGHT);
        header.addView(clock, new LinearLayout.LayoutParams(dp(120), dp(54)));
        root.addView(header);

        TextView subtitle = text("选择应用开始使用", 16, MUTED);
        subtitle.setPadding(0, 0, 0, dp(18));
        root.addView(subtitle);

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        appGrid = new GridLayout(this);
        appGrid.setColumnCount(5);
        appGrid.setAlignmentMode(GridLayout.ALIGN_BOUNDS);
        appGrid.setUseDefaultMargins(false);
        scroll.addView(appGrid, new ScrollView.LayoutParams(-1, -1));
        root.addView(scroll, new LinearLayout.LayoutParams(-1, 0, 1f));

        Button settings = actionButton("系统设置", "打开 Android 设置", v -> {
            try {
                startActivity(new Intent(Settings.ACTION_SETTINGS));
            } catch (Exception ignored) {
            }
        });
        LinearLayout.LayoutParams settingsParams = new LinearLayout.LayoutParams(dp(180), dp(66));
        settingsParams.gravity = Gravity.RIGHT;
        settingsParams.topMargin = dp(16);
        root.addView(settings, settingsParams);

        return root;
    }

    private void populateApps() {
        appGrid.removeAllViews();
        Intent query = new Intent(Intent.ACTION_MAIN);
        query.addCategory(Intent.CATEGORY_LAUNCHER);
        List<ResolveInfo> apps = getPackageManager().queryIntentActivities(query, 0);
        Collections.sort(apps, new Comparator<ResolveInfo>() {
            @Override
            public int compare(ResolveInfo left, ResolveInfo right) {
                String a = String.valueOf(left.loadLabel(getPackageManager()));
                String b = String.valueOf(right.loadLabel(getPackageManager()));
                return a.compareToIgnoreCase(b);
            }
        });

        List<ResolveInfo> filtered = new ArrayList<>();
        for (ResolveInfo info : apps) {
            if (!getPackageName().equals(info.activityInfo.packageName)) {
                filtered.add(info);
            }
        }

        if (filtered.isEmpty()) {
            TextView empty = text("没有找到可启动的应用", 20, MUTED);
            appGrid.addView(empty, gridParams());
            return;
        }

        for (final ResolveInfo info : filtered) {
            String label = String.valueOf(info.loadLabel(getPackageManager()));
            Button button = actionButton(label, info.activityInfo.packageName, v -> {
                Intent launch = new Intent(Intent.ACTION_MAIN);
                launch.addCategory(Intent.CATEGORY_LAUNCHER);
                launch.setClassName(info.activityInfo.packageName, info.activityInfo.name);
                launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                try {
                    startActivity(launch);
                } catch (Exception ignored) {
                }
            });
            appGrid.addView(button, gridParams());
        }
        if (appGrid.getChildCount() > 0) {
            appGrid.getChildAt(0).requestFocus();
        }
    }

    private GridLayout.LayoutParams gridParams() {
        GridLayout.Spec row = GridLayout.spec(GridLayout.UNDEFINED, 1);
        GridLayout.Spec column = GridLayout.spec(GridLayout.UNDEFINED, 1, 1f);
        GridLayout.LayoutParams params = new GridLayout.LayoutParams(row, column);
        params.width = 0;
        params.height = dp(112);
        params.setMargins(dp(6), dp(6), dp(6), dp(6));
        return params;
    }

    private Button actionButton(String title, String detail, View.OnClickListener listener) {
        Button button = new Button(this);
        button.setAllCaps(false);
        button.setText(title + "\n" + detail);
        button.setTextColor(TEXT);
        button.setTextSize(16);
        button.setGravity(Gravity.CENTER);
        button.setPadding(dp(8), dp(4), dp(8), dp(4));
        button.setFocusable(true);
        button.setOnClickListener(listener);
        button.setBackground(focusBackground(false));
        button.setOnFocusChangeListener((view, focused) -> view.setBackground(focusBackground(focused)));
        return button;
    }

    private GradientDrawable focusBackground(boolean focused) {
        GradientDrawable background = new GradientDrawable();
        background.setColor(focused ? Color.rgb(44, 64, 102) : PANEL);
        background.setCornerRadius(dp(12));
        background.setStroke(dp(focused ? 2 : 1), focused ? ACCENT : Color.rgb(48, 58, 76));
        return background;
    }

    private TextView text(String value, int size, int color) {
        TextView view = new TextView(this);
        view.setText(value);
        view.setTextSize(size);
        view.setTextColor(color);
        return view;
    }

    private void updateClock() {
        if (clock != null) {
            clock.setText(clockFormat.format(new Date()));
        }
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
