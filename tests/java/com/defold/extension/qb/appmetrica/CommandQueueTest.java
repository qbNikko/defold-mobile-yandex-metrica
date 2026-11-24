package com.defold.extension.qb.appmetrica;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

/** Проверяет порядок, фоновый поток и отказ без ожидания при заполненной очереди. */
public final class CommandQueueTest {
    private static final int TEST_TIMEOUT_SECONDS = 5;

    /** Запускает тест без Android SDK и сторонних зависимостей. */
    public static void main(String[] args) throws InterruptedException {
        CommandQueue queue = new CommandQueue(1);
        CountDownLatch started = new CountDownLatch(1);
        CountDownLatch releaseSdk = new CountDownLatch(1);
        CountDownLatch done = new CountDownLatch(1);
        AtomicReference<Thread> worker = new AtomicReference<>();
        List<Integer> calls = new ArrayList<>();
        try {
            check(queue.offer(() -> {
                worker.set(Thread.currentThread());
                calls.add(1);
                started.countDown();
                try {
                    releaseSdk.await(TEST_TIMEOUT_SECONDS, TimeUnit.SECONDS);
                } catch (InterruptedException interrupted) {
                    Thread.currentThread().interrupt();
                }
            }), "Первая команда должна приниматься");
            check(started.await(TEST_TIMEOUT_SECONDS, TimeUnit.SECONDS), "Фоновая команда не стартовала");
            check(worker.get() != Thread.currentThread(), "SDK запущен на вызывающем потоке");
            check(queue.offer(() -> {
                calls.add(2);
                done.countDown();
            }), "Очередь должна принять вторую команду при занятом SDK");
            check(!queue.offer(() -> calls.add(3)), "При переполнении требуется немедленный отказ");
            check(done.getCount() == 1, "Команды должны выполняться последовательно");
            releaseSdk.countDown();
            check(done.await(TEST_TIMEOUT_SECONDS, TimeUnit.SECONDS), "Вторая команда не завершилась");
            check(calls.equals(Arrays.asList(1, 2)), "Изменился порядок команд");
        } finally {
            releaseSdk.countDown();
            queue.shutdown();
        }
        check(!queue.offer(() -> {}), "Закрытая очередь не должна принимать команды");
        System.out.println("CommandQueueTest: OK");
    }

    /** Прерывает тест с сообщением, если условие оказалось ложным. */
    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
}
