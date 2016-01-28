package com.mapzen.tangram.android;

import android.app.Activity;
import android.os.Bundle;
import android.view.Window;
import android.widget.Toast;

import com.mapzen.tangram.DebugFlags;
import com.mapzen.tangram.HttpHandler;
import com.mapzen.tangram.LngLat;
import com.mapzen.tangram.MapController;
import com.mapzen.tangram.MapData;
import com.mapzen.tangram.MapView;
import com.mapzen.tangram.Properties;
import com.mapzen.tangram.Tangram;
import com.mapzen.tangram.Coordinates;

import com.mapzen.tangram.TouchInput;
import com.squareup.okhttp.Callback;

import java.io.File;
import java.lang.Math;

public class MainActivity extends Activity {

    MapController mapController;
    MapView mapView;
    MapData touchMarkers;

    boolean tileInfo;

    //String tileApiKey = "?api_key=vector-tiles-tyHL4AY";
    String tileApiKey = "?api_key=vector-tiles-VMSYhD4";

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        requestWindowFeature(Window.FEATURE_NO_TITLE);

        setContentView(R.layout.main);

        mapView = (MapView)findViewById(R.id.map);
        mapController = new MapController(this, mapView);
        mapController.setMapZoom(12);
        mapController.setMapPosition(-74.00976419448854, 40.70532700869127);

        final MapData touchMarkers = new MapData("touch");
        Tangram.addDataSource(touchMarkers);

        final LngLat lastTappedPoint = new LngLat();
        final String colors[] = {"blue", "red", "green" };
        final LngLat zeroCoord = new LngLat();
        final Coordinates line = new Coordinates();

        mapController.setTapResponder(new TouchInput.TapResponder() {
            @Override
            public boolean onSingleTapUp(float x, float y) {
                return false;
            }

            @Override
            public boolean onSingleTapConfirmed(float x, float y) {
                LngLat tapPoint = mapController.coordinatesAtScreenPosition(x, y);

                if (!lastTappedPoint.equals(zeroCoord)) {
                    Properties props = new Properties();
                    props.set("type", "line");
                    props.set("color", colors[(int)(Math.random() * 2.0 + 0.5)] );

                    line.clear();
                    line.add(tapPoint);
                    line.add(lastTappedPoint);
                    touchMarkers.addLine(props, line);

                    props = new Properties();
                    props.set("type", "point");
                    touchMarkers.addPoint(props, lastTappedPoint);
                }
                lastTappedPoint.set(tapPoint);

                mapController.pickFeature(x, y);

                mapController.setMapPosition(tapPoint.longitude, tapPoint.latitude, 1);

                return true;
            }
        });

        mapController.setDoubleTapResponder(new TouchInput.DoubleTapResponder() {
            @Override
            public boolean onDoubleTap(float x, float y) {
                mapController.setMapZoom(mapController.getMapZoom() + 1.f, .5f);
                LngLat tapped = mapController.coordinatesAtScreenPosition(x, y);
                LngLat current = mapController.getMapPosition();
                mapController.setMapPosition(
                        .5 * (tapped.longitude + current.longitude),
                        .5 * (tapped.latitude + current.latitude),
                        .5f
                );
                return true;
            }
        });

        mapController.setLongPressResponder(new TouchInput.LongPressResponder() {
            @Override
            public void onLongPress(float x, float y) {
                if (touchMarkers != null) {
                    touchMarkers.clear();
                }
                tileInfo = !tileInfo;
                Tangram.setDebugFlag(DebugFlags.TILE_INFOS, tileInfo);
            }
        });

        mapController.setFeatureTouchListener(new MapController.FeatureTouchListener() {
            @Override
            public void onTouch(Properties properties, float positionX, float positionY) {
                String name = properties.getString("name");
                if (name.length() == 0) {
                    name = "unnamed...";
                }
                Toast.makeText(getApplicationContext(),
                        "Selected: " + name + " at: " + positionX + ", " + positionY,
                        Toast.LENGTH_SHORT).show();
            }
        });

        HttpHandler handler = new HttpHandler() {
            @Override
            public boolean onRequest(String url, Callback cb) {
                url += tileApiKey;
                return super.onRequest(url, cb);
            }

            @Override
            public void onCancel(String url) {
                url += tileApiKey;
                super.onCancel(url);
            }
        };

        try {
            File httpCache = new File(getExternalCacheDir().getAbsolutePath() + "/tile_cache");
            handler.setCache(httpCache, 30 * 1024 * 1024);
        } catch (Exception e) {
            e.printStackTrace();
        }

        mapController.setHttpHandler(handler);

    }

}

