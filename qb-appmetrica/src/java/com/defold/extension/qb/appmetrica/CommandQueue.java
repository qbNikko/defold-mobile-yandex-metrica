package com.defold.extension.qb.appmetrica;

import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

/** Выполняет команды последовательно. Заполненная очередь отклоняет новые команды сразу. */
final class CommandQueue {
    private final ThreadPoolExecutor worker;

    /** Создаёт очередь с заданным числом ожидающих команд. */
    CommandQueue(int capacity) {
        worker = new ThreadPoolExecutor(
            1, 1, 0L, TimeUnit.MILLISECONDS, new ArrayBlockingQueue<>(capacity),
            task -> new Thread(task, "Defold-AppMetrica")
        );
    }

    /** Принимает Runnable. Возвращает false при переполнении или закрытии очереди. */
    boolean offer(Runnable task) {
        try {
            worker.execute(task);
            return true;
        } catch (RejectedExecutionException rejected) {
            return false;
        }
    }

    /** Прекращает приём и позволяет уже принятым командам закончить работу. */
    void shutdown() {
        worker.shutdown();
    }
}
